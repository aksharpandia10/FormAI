import SwiftUI
import AVKit

struct IntroView: View {
    let onGetStarted: () -> Void
    var onAlreadyHaveAccount: (() -> Void)? = nil
    @State private var showContent = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                PhoneMockupHero()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.94)
                    .animation(.spring(response: 0.65, dampingFraction: 0.82), value: showContent)

                VStack(spacing: 8) {
                    Text("Unlock perfect form.")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("AI-powered coaching for every rep.")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.4).delay(0.25), value: showContent)

                VStack(spacing: 16) {
                    Button(action: onGetStarted) {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    if let onAlreadyHaveAccount {
                        Button(action: onAlreadyHaveAccount) {
                            HStack(spacing: 4) {
                                Text("Already have an account?")
                                    .foregroundStyle(Theme.textSecondary)
                                Text("Sign In")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .font(.system(size: 14))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.42), value: showContent)
            }
        }
        .onAppear { showContent = true }
    }
}

// MARK: - Phone Mockup

private struct PhoneMockupHero: View {
    @State private var scanning = false
    @State private var pulsing = false

    var body: some View {
        GeometryReader { geo in
            let phoneH = min(geo.size.height * 0.88, 430.0)
            let phoneW = phoneH * 0.465
            let cornerR = phoneW * 0.19

            ZStack {
                // Ambient glow
                Ellipse()
                    .fill(Theme.primary.opacity(0.1))
                    .frame(width: phoneW * 1.5, height: phoneH * 0.45)
                    .blur(radius: 36)
                    .offset(y: phoneH * 0.08)

                // Device frame
                RoundedRectangle(cornerRadius: cornerR)
                    .fill(Color(white: 0.14))
                    .frame(width: phoneW, height: phoneH)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerR)
                            .stroke(Color(white: 0.28), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.38), radius: 28, x: 0, y: 14)

                // Screen
                ZStack {
                    Color.black

                    // Looping workout video
                    LoopingVideoPlayer(named: "intro_demo")

                    // Scanning line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Theme.accent.opacity(0.35), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(height: 55)
                        .offset(y: scanning ? 120 : -120)
                        .animation(
                            .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                            value: scanning
                        )

                    // Viewfinder brackets
                    ViewfinderBrackets()

                    // Analyzing badge
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .scaleEffect(pulsing ? 1.45 : 0.75)
                            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulsing)
                        Text("Analyzing...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(11)

                    // Form feedback chips
                    VStack(alignment: .leading, spacing: 5) {
                        IntroFormChip(label: "Back angle", ok: true)
                        IntroFormChip(label: "Knee tracking", ok: true)
                        IntroFormChip(label: "Squat depth", ok: false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(11)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerR - 5))
                .frame(width: phoneW - 11, height: phoneH - 11)

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                scanning = true
                pulsing = true
            }
        }
    }
}

// MARK: - Looping Video Player

private struct LoopingVideoPlayer: UIViewRepresentable {
    let named: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        guard let url = Bundle.main.url(forResource: named, withExtension: "mp4") else {
            return view
        }
        let player = AVQueuePlayer()
        player.isMuted = true
        let looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        context.coordinator.player = player
        context.coordinator.looper = looper
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}

    class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }
}

private final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}


// MARK: - Viewfinder Brackets

private struct ViewfinderBrackets: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let inset: CGFloat = 18
            let arm: CGFloat = 18
            let thick: CGFloat = 2.2
            let color = Color.white.opacity(0.5)

            ZStack {
                bracketPath(origin: CGPoint(x: inset, y: inset), arm: arm, flipH: false, flipV: false)
                    .stroke(color, style: StrokeStyle(lineWidth: thick, lineCap: .round))
                bracketPath(origin: CGPoint(x: w - inset, y: inset), arm: arm, flipH: true, flipV: false)
                    .stroke(color, style: StrokeStyle(lineWidth: thick, lineCap: .round))
                bracketPath(origin: CGPoint(x: inset, y: h - inset), arm: arm, flipH: false, flipV: true)
                    .stroke(color, style: StrokeStyle(lineWidth: thick, lineCap: .round))
                bracketPath(origin: CGPoint(x: w - inset, y: h - inset), arm: arm, flipH: true, flipV: true)
                    .stroke(color, style: StrokeStyle(lineWidth: thick, lineCap: .round))
            }
        }
    }

    private func bracketPath(origin: CGPoint, arm: CGFloat, flipH: Bool, flipV: Bool) -> Path {
        let dx: CGFloat = flipH ? -arm : arm
        let dy: CGFloat = flipV ? -arm : arm
        var p = Path()
        p.move(to: CGPoint(x: origin.x + dx, y: origin.y))
        p.addLine(to: origin)
        p.addLine(to: CGPoint(x: origin.x, y: origin.y + dy))
        return p
    }
}

// MARK: - Form Chip

private struct IntroFormChip: View {
    let label: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
                .font(.system(size: 11))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.6))
        .clipShape(Capsule())
    }
}

#Preview {
    IntroView(onGetStarted: {})
}
