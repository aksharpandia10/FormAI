import SwiftUI

struct ExerciseHomeView: View {
    var onSignOut: (() -> Void)? = nil
    @StateObject private var auth = AuthService.shared
    @State private var searchText = ""
    @State private var showSettings = false
    private var searchResults: [Exercise] {
        guard !searchText.isEmpty else { return [] }
        let q = searchText.lowercased()
        return ExerciseLibrary.all.filter { ex in
            ex.name.lowercased().contains(q) ||
            ex.muscleGroups.joined().lowercased().contains(q) ||
            ex.searchTerms.joined().lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                searchBar
                if searchText.isEmpty {
                    tileGrid
                } else {
                    searchResultsList
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationDestination(for: ExerciseCategory.self) { cat in
                ExerciseCategoryView(category: cat)
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
            .navigationDestination(isPresented: $showSettings) {
                FormAISettingsView(onSignOut: onSignOut)
            }
        }
        .task { await FormCheckHistoryService.shared.prefetch() }
        .onChange(of: searchText) { oldValue, newValue in
            if oldValue.isEmpty && !newValue.isEmpty {
                AnalyticsService.searchStarted()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Form AI")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Choose an exercise to check your form")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
            TextField(text: $searchText, prompt: Text("Search exercises...").foregroundStyle(Color(hex: "#8A8A8A"))) { }
                .foregroundStyle(Theme.textPrimary)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Tile grid

    private var tileGrid: some View {
        ScrollView {
            VStack(spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(ExerciseCategory.allCases) { cat in
                        NavigationLink(value: cat) {
                            CategoryTile(category: cat)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            AnalyticsService.categoryTapped(category: cat.rawValue)
                        })
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Search results

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchResults) { exercise in
                    NavigationLink(value: exercise) {
                        ExerciseRow(exercise: exercise)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        AnalyticsService.searchResultTapped(query: searchText, exerciseId: exercise.id, exerciseName: exercise.name)
                    })
                    if exercise.id != searchResults.last?.id {
                        Divider().padding(.leading, 24)
                    }
                }
            }
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Category Tile

struct CategoryTile: View {
    let category: ExerciseCategory

    private var count: Int {
        ExerciseLibrary.countByCategory[category] ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(category.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
            Spacer()
            VStack(alignment: .leading, spacing: 3) {
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text("\(count) exercises")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(height: 110)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Recent Workouts Tile

struct RecentWorkoutsTile: View {
    let entries: [FormCheckEntry]

    private var recent: [FormCheckEntry] { Array(entries.prefix(3)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            VStack(spacing: 0) {
                ForEach(recent) { entry in
                    if let exercise = ExerciseLibrary.all.first(where: { $0.id == entry.exerciseId }) {
                        NavigationLink(destination: FormCheckResultView(
                            result: FormCheckResult(exercise: exercise, entry: entry),
                            skipSave: true,
                            onDone: { }
                        )) {
                            HStack(spacing: 12) {
                                if !exercise.imageName.isEmpty {
                                    Image(exercise.imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 9))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.exerciseName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(scoreColor(entry.score).opacity(0.12))
                                        .frame(width: 40, height: 40)
                                    Text("\(entry.score)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(scoreColor(entry.score))
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if entry.id != recent.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return .green
        case 60...: return .orange
        default: return .red
        }
    }
}

// MARK: - Exercise Category View (drill-down)

struct ExerciseCategoryView: View {
    let category: ExerciseCategory

    private var exercises: [Exercise] {
        ExerciseLibrary.byCategory[category] ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(category.rawValue)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                LazyVStack(spacing: 0) {
                    ForEach(exercises) { exercise in
                        NavigationLink(value: exercise) {
                            ExerciseRow(exercise: exercise)
                        }
                        .buttonStyle(.plain)
                        if exercise.id != exercises.last?.id {
                            Divider().padding(.leading, 24)
                        }
                    }
                }
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
    }
}

private struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            Image(exercise.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(exercise.muscleGroups.prefix(2).joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
