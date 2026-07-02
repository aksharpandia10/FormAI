import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise
    var source: String = "browse"

    @Environment(\.dismiss) private var dismiss
    @State private var history: [FormCheckEntry] = []
    @State private var showTutorial = false
    @State private var navigateToRecording = false
    @State private var historyExpanded = true
    @State private var historyLoadFailed = false
    @State private var showRecordingTip = false
    @State private var selectedHistoryEntry: FormCheckEntry? = nil
    @State private var showHistoryResult = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Title
                Text(exercise.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                // Metadata tags
                HStack(spacing: 8) {
                    chip(exercise.equipment, color: Theme.primary)
                    chip("\(exercise.cameraAngle.rawValue) cam", color: Theme.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)

                // Check Form CTA
                Button {
                    AnalyticsService.formCheckTapped(exerciseId: exercise.id, exerciseName: exercise.name)
                    showRecordingTip = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Check My Form")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)

                // Past Analyses
                if !history.isEmpty {
                    historySection
                } else if historyLoadFailed {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                        Text("Couldn't load past analyses")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Button("Retry") {
                            Task { @MainActor in await loadHistory() }
                        }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                    }
                    .padding(.horizontal, 24)
                }

                // Watch Tutorial
                Button { showTutorial = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Theme.textSecondary)
                        Text("Watch Tutorial")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary.opacity(0.6))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                // How to Perform
                VStack(alignment: .leading, spacing: 0) {
                    Text("HOW TO PERFORM")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .kerning(0.8)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 14)
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(i + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.primary)
                                .frame(width: 22, height: 22)
                                .background(Theme.primary.opacity(0.1))
                                .clipShape(Circle())
                            Text(step)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)

                Color.clear.frame(height: 24)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .navigationDestination(isPresented: $showTutorial) {
            TutorialView(exerciseName: exercise.name)
        }
        .navigationDestination(isPresented: $navigateToRecording) {
            VideoRecordingView(exercise: exercise)
        }
        .navigationDestination(isPresented: $showHistoryResult) {
            if let entry = selectedHistoryEntry {
                FormCheckResultView(
                    result: FormCheckResult(exercise: exercise, entry: entry),
                    skipSave: true,
                    onDone: { }
                )
            }
        }
        .fullScreenCover(isPresented: $showRecordingTip) {
            RecordingTipView(exercise: exercise) {
                showRecordingTip = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    navigateToRecording = true
                }
            }
        }
        .task {
            await loadHistory()
            AnalyticsService.exerciseOpened(id: exercise.id, name: exercise.name, source: source)
        }
    }

    private func loadHistory() async {
        let cached = await FormCheckHistoryService.shared.cachedHistory(for: exercise.id)
        if !cached.isEmpty { history = cached }
        do {
            history = try await FormCheckHistoryService.shared.loadHistory(for: exercise.id)
            historyLoadFailed = false
        } catch {
            if history.isEmpty { historyLoadFailed = true }
        }
    }

    private var historySection: some View {
        VStack(spacing: 0) {
            // Dropdown header
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    historyExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Past Analyses")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(history.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                        .rotationEffect(.degrees(historyExpanded ? 180 : 0))
                }
                .padding(18)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: historyExpanded ? 0 : 16,
                                            style: .continuous))
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: historyExpanded ? 0 : 16,
                    bottomTrailingRadius: historyExpanded ? 0 : 16,
                    topTrailingRadius: 16
                ))
            }
            .buttonStyle(.plain)

            if historyExpanded {
                VStack(spacing: 0) {
                    Divider()
                    ForEach(history.prefix(5)) { entry in
                        Button {
                            selectedHistoryEntry = entry
                            showHistoryResult = true
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(scoreColor(entry.score).opacity(0.12))
                                        .frame(width: 42, height: 42)
                                    Text("\(entry.score)")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(scoreColor(entry.score))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(entry.summary)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        if entry.id != history.prefix(5).last?.id {
                            Divider().padding(.leading, 74)
                        }
                    }
                }
                .background(Theme.cardBackground)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 24)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return Color(hex: "#22C55E") }
        if score >= 60 { return Color(hex: "#F59E0B") }
        return Color(hex: "#EF4444")
    }

    @ViewBuilder
    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

struct HistoryEntryRow: View {
    let entry: FormCheckEntry

    var scoreColor: Color {
        if entry.score >= 80 { return .green }
        if entry.score >= 60 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(scoreColor.opacity(0.12)).frame(width: 44, height: 44)
                Text("\(entry.score)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(scoreColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(entry.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}
