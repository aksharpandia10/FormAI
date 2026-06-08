import SwiftUI

// MARK: - Confetti particle

private struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let xDrift: CGFloat
    let speed: CGFloat
}

private struct ConfettiView: View {
    @State private var particles: [Particle] = []
    @State private var timer: Timer?

    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink,
        Color(hex: "#FF6B6B"), Color(hex: "#4ECDC4"), Color(hex: "#FFE66D")
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 0.4)
                        .rotationEffect(.degrees(p.rotation))
                        .position(x: p.x, y: p.y)
                        .opacity(p.y < geo.size.height * 0.85 ? 1 : 0)
                }
            }
            .onAppear {
                for i in 0..<60 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.03) {
                        particles.append(Particle(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: -10,
                            color: colors.randomElement()!,
                            size: CGFloat.random(in: 8...14),
                            rotation: Double.random(in: 0...360),
                            xDrift: CGFloat.random(in: -40...40),
                            speed: CGFloat.random(in: 2...5)
                        ))
                    }
                }
                timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                    for i in particles.indices {
                        particles[i].y += particles[i].speed
                        particles[i].x += particles[i].xDrift * 0.016
                    }
                    particles.removeAll { $0.y > geo.size.height + 20 }
                    if particles.isEmpty { timer?.invalidate() }
                }
            }
            .onDisappear { timer?.invalidate() }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Result View

struct FormCheckResultView: View {
    let result: FormCheckResult
    var skipSave: Bool = false
    let onDone: () -> Void

    @Environment(\.dismiss) private var selfDismiss
    @State private var didSave = false
    @State private var doneTapped = false
    @State private var animateScore = false
    @State private var showConfetti = false
    @State private var displayedScore = 0
    @State private var showHowItWorks = false
    @State private var selectedFrameIndex: Int? = nil
    @State private var shareImage: UIImage? = nil
    @State private var showShare = false
    @State private var showBestResultsTip = false

    var scoreColor: Color {
        if result.entry.score >= 80 { return Color(hex: "#22C55E") }
        if result.entry.score >= 60 { return Color(hex: "#F59E0B") }
        return Color(hex: "#EF4444")
    }

    var scoreMoji: String {
        if result.entry.score >= 80 { return "🔥" }
        if result.entry.score >= 60 { return "💪" }
        return "🔧"
    }

    var scoreLabel: String {
        if result.entry.score >= 80 { return "Crushing it!" }
        if result.entry.score >= 60 { return "Almost there" }
        return "Needs work"
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 16) {
                    scoreCard
                    if !result.entry.improve.isEmpty { improveCard }
                    if !result.entry.didWell.isEmpty { didWellCard }
                    if !result.frames.isEmpty { framesStrip }
                    doneButton
                    bestResultsDisclaimer
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Theme.background.ignoresSafeArea())

            if showConfetti { ConfettiView().ignoresSafeArea() }
        }
        .navigationTitle(result.exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    guard !doneTapped else { return }
                    doneTapped = true
                    onDone(); selfDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        shareImage = renderShareCard(entry: result.entry, exerciseName: result.exercise.name)
                        showShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Button { showHowItWorks = true } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showHowItWorks) { HowItWorksSheet() }
        .sheet(isPresented: $showBestResultsTip) { BestResultsTipSheet() }
        .sheet(isPresented: $showShare) {
            if let img = shareImage {
                ShareSheet(items: [img])
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedFrameIndex != nil },
            set: { if !$0 { selectedFrameIndex = nil } }
        )) {
            if let i = selectedFrameIndex {
                FrameDetailSheet(index: i, image: result.frames[i], total: result.frames.count)
            }
        }
        .task {
            guard !didSave else { return }
            didSave = true
            if !skipSave { try? await FormCheckHistoryService.shared.save(result.entry) }

            if skipSave {
                // History replay: show score immediately, just animate the ring
                displayedScore = result.entry.score
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15)) {
                    animateScore = true
                }
            } else {
                // New result: count-up animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15)) {
                    animateScore = true
                }
                let target = result.entry.score
                let steps = 30
                for i in 1...steps {
                    try? await Task.sleep(nanoseconds: 20_000_000)
                    await MainActor.run {
                        displayedScore = Int(Double(target) * Double(i) / Double(steps))
                    }
                }
                if result.entry.score >= 80 {
                    showConfetti = true
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    showConfetti = false
                }
            }
        }
    }

    // MARK: - Score Card

    private var scoreCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(scoreMoji) \(scoreLabel)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(result.entry.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(scoreColor.opacity(0.12))
                    .frame(width: 72, height: 72)
                Circle()
                    .trim(from: 0, to: animateScore ? CGFloat(result.entry.score) / 100 : 0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.9), value: animateScore)
                VStack(spacing: 0) {
                    Text("\(displayedScore)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(scoreColor)
                        .contentTransition(.numericText())
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

    // MARK: - Improve Card

    private var improveCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("⚡️")
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("FIX THESE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .kerning(0.8)
                    Text("Tactical improvements")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)

            VStack(spacing: 0) {
                ForEach(Array(result.entry.improve.enumerated()), id: \.offset) { i, bullet in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#EF4444").opacity(0.12))
                                .frame(width: 26, height: 26)
                            Text("\(i + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: "#EF4444"))
                        }
                        improveBulletText(bullet)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)

                    if i < result.entry.improve.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .padding(.bottom, 4)
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color(hex: "#EF4444").opacity(0.2), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Did Well Card

    private var didWellCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("✨")
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOU NAILED")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .kerning(0.8)
                    Text("What went well")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)

            VStack(spacing: 0) {
                ForEach(Array(result.entry.didWell.enumerated()), id: \.offset) { i, bullet in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#22C55E").opacity(0.12))
                                .frame(width: 26, height: 26)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#22C55E"))
                        }
                        Text(bullet)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)

                    if i < result.entry.didWell.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .padding(.bottom, 4)
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color(hex: "#22C55E").opacity(0.2), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Frames Strip

    private var framesStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("📽️ Analyzed Frames")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .kerning(0.5)
                Spacer()
                Text("\(result.frames.count) frames")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(result.frames.enumerated()), id: \.offset) { i, image in
                        Button {
                            selectedFrameIndex = i
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 120)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Text("\(i + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Improve bullet helper

    @ViewBuilder
    private func improveBulletText(_ bullet: String) -> some View {
        // Split on "(frame" to separate the action from the citation
        if let range = bullet.range(of: "(frame", options: .caseInsensitive) {
            let action = String(bullet[bullet.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let citation = String(bullet[range.lowerBound...])
            (Text(action).font(.system(size: 14)).foregroundStyle(Theme.textPrimary)
             + Text(" \(citation)").font(.system(size: 13)).foregroundStyle(Theme.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(bullet)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Best Results Disclaimer

    private var bestResultsDisclaimer: some View {
        Button {
            showBestResultsTip = true
        } label: {
            Text("Not the results you expected?")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .underline()
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button {
            guard !doneTapped else { return }
            doneTapped = true
            onDone()
            selfDismiss()
        } label: {
            Text("Done")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(doneTapped)
        .padding(.top, 4)
    }
}

// MARK: - Best Results Tip Sheet

private struct BestResultsTipSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("The AI works best when it can clearly see your full movement. Here's how to get the most accurate analysis.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 20) {
                        TipItem(emoji: "⏱️", title: "Keep it under 10 seconds",
                                detail: "One or two clean reps is all we need. Longer videos dilute the analysis and can confuse the AI.")
                        TipItem(emoji: "📐", title: "Film from the right angle",
                                detail: "Each exercise shows the required angle before you record. Side view captures depth and spine; front view captures alignment.")
                        TipItem(emoji: "🔄", title: "Show 1–2 complete reps",
                                detail: "Start recording just before you begin the movement, and stop right after you finish. Don't include long setup or rest periods.")
                        TipItem(emoji: "👤", title: "Keep your full body in frame",
                                detail: "Make sure your feet, hips, and head are all visible. Cropped frames mean missed cues.")
                    }
                }
                .padding(24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Tips for Best Results")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }
        }
    }
}

private struct TipItem: View {
    let emoji: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 40, height: 40)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Frame helpers

private struct FrameDetailSheet: View {
    let index: Int
    let image: UIImage
    let total: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Frame \(index + 1) of \(total)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - How It Works Sheet

private struct HowItWorksSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(emoji: String, title: String, body: String)] = [
        ("🎬", "Video to frames",
         "Your video is sampled into up to 100 evenly spaced frames covering every phase of the lift — setup through lockout."),

        ("🤖", "AI analysis",
         "Claude analyzes each frame against expert coaching standards specific to your exercise, focusing only on frames where you're mid-rep."),

        ("⚡️", "Actionable cues",
         "Improvements are phrased as direct instructions — what to do next session, not just what went wrong. Safety-critical issues always come first."),

        ("🎯", "Your score",
         "0–100. 90+ = near perfect. 70–89 = good with minor fixes. 50–69 = clear issues to work on. Below 50 = significant problems that need attention."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Powered by Gemini AI, analyzing your movement against exercise-specific coaching standards.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(steps, id: \.title) { step in
                            HStack(alignment: .top, spacing: 14) {
                                Text(step.emoji)
                                    .font(.system(size: 22))
                                    .frame(width: 40, height: 40)
                                    .background(Theme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.title)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(step.body)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    Text("Form AI is a coaching aid, not a medical device. Always prioritise pain-free movement and consult a professional if you have any injuries or concerns.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))
                        .padding(.top, 8)
                }
                .padding(24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }
        }
    }
}
