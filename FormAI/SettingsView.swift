import SwiftUI
import RevenueCatUI
#if DEBUG
import Photos
#endif

struct FormAISettingsView: View {
    var onSignOut: (() -> Void)? = nil
    @StateObject private var auth = AuthService.shared
    @StateObject private var sub = SubscriptionService.shared
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showDeleteError = false
    @State private var isDeleting = false
    @State private var showCustomerCenter = false
    @State private var showTerms = false
    @State private var showPrivacy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: Subscription
                sectionHeader("Subscription")
                cardGroup {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 20))
                        Text("Form AI Pro")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                    }
                    .padding(18)

                    if sub.isSubscribed {
                        Divider().padding(.leading, 18)
                        Button {
                            showCustomerCenter = true
                        } label: {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(Theme.primary)
                                Text("Manage Subscription")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(18)
                        }
                    }
                }

                // MARK: Account
                sectionHeader("Account")
                cardGroup {
                    if let user = auth.user {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(Theme.primary)
                                .font(.system(size: 20))
                            Text(user.displayName ?? user.email ?? "Signed in")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                        }
                        .padding(18)

                        Divider().padding(.leading, 18)
                    }

                    Button { showSignOutConfirm = true } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.red)
                            Text("Sign Out")
                                .font(.system(size: 16))
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(18)
                    }

                    Divider().padding(.leading, 18)

                    Button { showDeleteConfirm = true } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                            Text("Delete Account")
                                .font(.system(size: 16))
                                .foregroundStyle(.red)
                            Spacer()
                            if isDeleting {
                                ProgressView().tint(.red)
                            }
                        }
                        .padding(18)
                    }
                    .disabled(isDeleting)
                }
                // MARK: Legal
                sectionHeader("Legal")
                cardGroup {
                    Button { showTerms = true } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(Theme.primary)
                            Text("Terms of Service")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(18)
                    }

                    Divider().padding(.leading, 18)

                    Button { showPrivacy = true } label: {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundStyle(Theme.primary)
                            Text("Privacy Policy")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(18)
                    }
                }

                #if DEBUG
                // MARK: Developer (DEBUG only)
                sectionHeader("Developer")
                cardGroup {
                    NavigationLink(destination: MarketingGalleryView()) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .foregroundStyle(Theme.primary)
                            Text("Marketing Screenshots (preview)")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(18)
                    }

                    Divider().padding(.leading, 18)

                    NavigationLink(destination: MarketingExportView()) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.on.square")
                                .foregroundStyle(Theme.primary)
                            Text("Export All to Photos")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(18)
                    }
                }
                #endif

            }
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                UserDefaults.standard.set(false, forKey: "formAI_hasCompletedOnboarding")
                try? auth.signOut()
                onSignOut?()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete Account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                isDeleting = true
                Task {
                    do {
                        try await auth.deleteAccount()
                        UserDefaults.standard.set(false, forKey: "formAI_hasCompletedOnboarding")
                        onSignOut?()
                    } catch {
                        showDeleteError = true
                    }
                    isDeleting = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all form check history. This cannot be undone.")
        }
        .alert("Unable to Delete Account", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please sign out and sign back in, then try again.")
        }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
        }
        .sheet(isPresented: $showTerms) { TermsOfServiceView() }
        .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func cardGroup<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

#if DEBUG
// MARK: - Marketing Screenshot Gallery (DEBUG only)
//
// Hidden tool for generating marketing screenshots of the form analysis
// screen with mock data. Never compiled into Release builds. Reachable from
// Settings → Developer → Marketing Screenshots. No user data is written
// (skipSave: true) and no names appear anywhere.

struct MarketingGalleryView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(ExerciseLibrary.all) { exercise in
                    HStack(spacing: 12) {
                        Text(exercise.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        NavigationLink {
                            FormCheckResultView(
                                result: MarketingMock.result(for: exercise, score: 95),
                                skipSave: true,
                                onDone: {}
                            )
                        } label: {
                            marketingScorePill(95, color: Color(hex: "#22C55E"))
                        }
                        NavigationLink {
                            FormCheckResultView(
                                result: MarketingMock.result(for: exercise, score: 54),
                                skipSave: true,
                                onDone: {}
                            )
                        } label: {
                            marketingScorePill(54, color: Color(hex: "#F59E0B"))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    Divider().padding(.leading, 18)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Marketing Screenshots")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func marketingScorePill(_ score: Int, color: Color) -> some View {
        Text("\(score)")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 44, height: 32)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

enum MarketingMock {
    private enum Lift { case squat, deadlift, bench, generic }

    private static func lift(for exercise: Exercise) -> Lift {
        let n = exercise.name.lowercased()
        if n.contains("deadlift") { return .deadlift }
        if n.contains("bench")    { return .bench }
        if n.contains("squat")    { return .squat }
        return .generic
    }

    private static func feedback(for lift: Lift, good: Bool) -> (didWell: [String], improve: [String], summary: String) {
        switch (lift, good) {
        case (.squat, true):
            return (
                ["Hit depth with the hip crease below the knee",
                 "Knees tracked in line with your toes",
                 "Braced torso stayed upright out of the hole",
                 "Bar path stayed stacked over midfoot"],
                ["Drive your knees out a touch harder on the way up to stay even (frame 7)"],
                "Textbook squat — great depth, an upright torso, and the bar tracking right over midfoot the whole way."
            )
        case (.squat, false):
            return (
                ["Solid stance width and foot placement",
                 "Consistent bar position on your back"],
                ["Stop your knees from caving in — drive them out over your toes (frame 5)",
                 "Hit more depth; you're stopping above parallel (frame 4)",
                 "Keep your chest up — you're tipping forward out of the bottom (frame 8)"],
                "You've got the basics, but knee cave and an early forward lean are leaking power and stressing your lower back."
            )
        case (.deadlift, true):
            return (
                ["Flat, neutral spine from setup to lockout",
                 "Bar stayed close to your legs the entire pull",
                 "Hips and shoulders rose at the same rate",
                 "Full, controlled lockout without overextending"],
                ["Engage your lats a touch sooner to lock the bar in off the floor (frame 3)"],
                "Strong, safe pull — neutral spine, bar tight to the body, and a clean lockout with hips and shoulders finishing together."
            )
        case (.deadlift, false):
            return (
                ["Strong initial drive off the floor",
                 "Good grip and hand placement on the bar"],
                ["Keep your lower back flat — it's rounding under load (frame 4)",
                 "Pull the bar back into your shins; it's drifting in front of you (frame 6)",
                 "Set your hips lower at the start to get behind the bar (frame 2)"],
                "Decent power off the floor, but a rounding lower back and the bar drifting forward are putting your spine at risk."
            )
        case (.bench, true):
            return (
                ["Stable arch with shoulder blades pinned back",
                 "Bar touched the lower chest in a consistent groove",
                 "Elbows tucked around 45–75° off your torso",
                 "Smooth, even lockout with both arms together"],
                ["Drive your feet into the floor a bit harder for leg drive (frame 6)"],
                "Clean, powerful press — tight upper back, a controlled bar path to the lower chest, and elbows tucked at a safe angle."
            )
        case (.bench, false):
            return (
                ["Even grip width and stable wrist position",
                 "Consistent touch point on each rep"],
                ["Tuck your elbows — they're flaring near 90° and stressing your shoulders (frame 5)",
                 "Control the descent; you're bouncing the bar off your chest (frame 7)",
                 "Keep your shoulder blades pinched back and down (frame 3)"],
                "You're moving the weight, but flaring elbows and a bouncing bar are costing you your shoulders and your press."
            )
        case (.generic, true):
            return (
                ["Strong, stable setup before every rep",
                 "Consistent path through the full range of motion",
                 "Great depth with no loss of tension at the bottom",
                 "Smooth, controlled tempo on the way down"],
                ["Brace your core a touch harder at the top to fully lock in the position (frame 8)"],
                "Excellent control and textbook positioning throughout. Just one small refinement to make it perfect."
            )
        case (.generic, false):
            return (
                ["Solid starting stance and grip width",
                 "Kept a steady rhythm across your reps"],
                ["Keep your spine neutral — you're rounding under load (frame 4)",
                 "Drive through your heels instead of shifting onto your toes (frame 6)",
                 "Control the descent; you're dropping too fast to stay tight (frame 9)"],
                "Some solid fundamentals here, but a few positioning issues are costing you tension and putting stress on the wrong areas."
            )
        }
    }

    static func result(for exercise: Exercise, score: Int) -> FormCheckResult {
        let fb = feedback(for: lift(for: exercise), good: score >= 80)
        let entry = FormCheckEntry(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            score: score,
            didWell: fb.didWell,
            improve: fb.improve,
            summary: fb.summary
        )
        return FormCheckResult(exercise: exercise, entry: entry)
    }
}

// MARK: - Static screenshot render of the analysis result (final state, no animation)
//
// Mirrors FormCheckResultView's card layout but in a fixed-width, final
// state so it renders correctly through ImageRenderer (which doesn't run
// .task or animations). Width matches an iPhone Pro point width.

struct ScreenshotResultView: View {
    let exercise: Exercise
    let entry: FormCheckEntry

    private let renderWidth: CGFloat = 393  // iPhone 16 Pro point width

    private var scoreColor: Color {
        if entry.score >= 80 { return Color(hex: "#22C55E") }
        if entry.score >= 60 { return Color(hex: "#F59E0B") }
        return Color(hex: "#EF4444")
    }
    private var scoreMoji: String {
        if entry.score >= 80 { return "🔥" }
        if entry.score >= 60 { return "💪" }
        return "🔧"
    }
    private var scoreLabel: String {
        if entry.score >= 80 { return "Crushing it!" }
        if entry.score >= 60 { return "Almost there" }
        return "Needs work"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Mock nav title
            Text(exercise.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

            scoreCard
            improveCard
            didWellCard
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
        .frame(width: renderWidth)
        .background(Theme.background)
    }

    private var scoreCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(scoreMoji) \(scoreLabel)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(entry.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            ZStack {
                Circle().fill(scoreColor.opacity(0.12)).frame(width: 72, height: 72)
                Circle()
                    .trim(from: 0, to: CGFloat(entry.score) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(entry.score)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(scoreColor)
                    Text("/ 100")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [scoreColor.opacity(0.12), scoreColor.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(scoreColor.opacity(0.25), lineWidth: 1.5))
        )
    }

    private var improveCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("⚡️").font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("FIX THESE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textSecondary).kerning(0.8)
                    Text("Tactical improvements")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 14)

            VStack(spacing: 0) {
                ForEach(Array(entry.improve.enumerated()), id: \.offset) { i, bullet in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle().fill(Color(hex: "#EF4444").opacity(0.12)).frame(width: 26, height: 26)
                            Text("\(i + 1)").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: "#EF4444"))
                        }
                        Text(bullet).font(.system(size: 14)).foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    if i < entry.improve.count - 1 { Divider().padding(.leading, 56) }
                }
            }
            .padding(.bottom, 4)
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(hex: "#EF4444").opacity(0.2), lineWidth: 1.5))
    }

    private var didWellCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("✨").font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOU NAILED")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textSecondary).kerning(0.8)
                    Text("What went well")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 14)

            VStack(spacing: 0) {
                ForEach(Array(entry.didWell.enumerated()), id: \.offset) { i, bullet in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle().fill(Color(hex: "#22C55E").opacity(0.12)).frame(width: 26, height: 26)
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: "#22C55E"))
                        }
                        Text(bullet).font(.system(size: 14)).foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    if i < entry.didWell.count - 1 { Divider().padding(.leading, 56) }
                }
            }
            .padding(.bottom, 4)
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(hex: "#22C55E").opacity(0.2), lineWidth: 1.5))
    }
}

// MARK: - Bulk exporter: renders every exercise at 95 and 54 to Photos

struct MarketingExportView: View {
    @State private var isExporting = false
    @State private var progress = 0
    @State private var total = ExerciseLibrary.all.count * 2
    @State private var doneCount: Int? = nil
    @State private var failed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Renders all \(ExerciseLibrary.all.count) exercises at score 95 and 54 (\(total) images) and saves them to your Photos library.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                if isExporting {
                    VStack(spacing: 10) {
                        ProgressView(value: Double(progress), total: Double(total))
                            .tint(Theme.primary)
                        Text("\(progress) / \(total)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 24)
                } else if let doneCount {
                    Text("✅ Saved \(doneCount) images to Photos")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#22C55E"))
                } else if failed {
                    Text("Photo library access denied. Enable it in Settings.")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    Task { await exportAll() }
                } label: {
                    Text(isExporting ? "Exporting…" : "Export All to Photos")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isExporting ? Theme.primary.opacity(0.5) : Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isExporting)
                .padding(.horizontal, 24)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Export Screenshots")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func exportAll() async {
        // Request add-only permission first
        let status = await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { cont.resume(returning: $0) }
        }
        guard status == .authorized || status == .limited else {
            failed = true
            return
        }

        isExporting = true
        doneCount = nil
        progress = 0

        for exercise in ExerciseLibrary.all {
            for score in [95, 54] {
                let entry = MarketingMock.result(for: exercise, score: score).entry
                let view = ScreenshotResultView(exercise: exercise, entry: entry)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 3
                if let img = renderer.uiImage {
                    UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                }
                progress += 1
                // Small yield so the UI updates and Photos isn't overwhelmed
                try? await Task.sleep(nanoseconds: 60_000_000)
            }
        }

        isExporting = false
        doneCount = progress
    }
}
#endif
