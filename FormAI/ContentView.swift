import SwiftUI

enum AppState {
    case loading
    case intro
    case onboarding
    case signIn
    case launching  // fun loading screen before home
    case home
}

struct ContentView: View {
    @StateObject private var auth = AuthService.shared
    @State private var appState: AppState = .loading
    @State private var onboardingReturnStep = 0
    @State private var showSignInSheet = false

    private var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "formAI_hasCompletedOnboarding")
    }

    var body: some View {
        Group {
            switch appState {
            case .loading:
                ZStack {
                    Theme.background.ignoresSafeArea()
                    ProgressView().tint(Theme.primary)
                }

            case .intro:
                IntroView(onGetStarted: {
                    withAnimation(.easeInOut(duration: 0.4)) { appState = .onboarding }
                }, onAlreadyHaveAccount: {
                    showSignInSheet = true
                })
                .sheet(isPresented: $showSignInSheet) {
                    SignInSheet(
                        onSignedIn: {
                            showSignInSheet = false
                            UserDefaults.standard.set(true, forKey: "formAI_hasCompletedOnboarding")
                            withAnimation(.easeInOut(duration: 0.4)) { appState = .launching }
                        },
                        onDismiss: { showSignInSheet = false }
                    )
                    .presentationDetents([.height(300)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.background)
                }

            case .onboarding:
                FormAIOnboardingView(
                    onComplete: {
                        onboardingReturnStep = 0
                        withAnimation(.easeInOut(duration: 0.4)) { appState = .signIn }
                    },
                    onBack: {
                        onboardingReturnStep = 0
                        withAnimation(.easeInOut(duration: 0.4)) { appState = .intro }
                    },
                    initialStep: onboardingReturnStep
                )

            case .signIn:
                SaveProgressView(
                    onSignedIn: {
                        AnalyticsService.onboardingCompleted()
                        UserDefaults.standard.set(true, forKey: "formAI_hasCompletedOnboarding")
                        Task { await FormAIOnboardingData.uploadPendingDataIfNeeded() }
                        withAnimation(.easeInOut(duration: 0.4)) { appState = .launching }
                    },
                    onSkip: {
                        AnalyticsService.signInSkipped()
                        AnalyticsService.onboardingCompleted()
                        UserDefaults.standard.set(true, forKey: "formAI_hasCompletedOnboarding")
                        withAnimation(.easeInOut(duration: 0.4)) { appState = .launching }
                    },
                    onBack: {
                        onboardingReturnStep = 8
                        withAnimation(.easeInOut(duration: 0.3)) { appState = .onboarding }
                    }
                )

            case .launching:
                LaunchLoadingView {
                    withAnimation(.easeInOut(duration: 0.5)) { appState = .home }
                }

            case .home:
                ExerciseHomeView(onSignOut: {
                    withAnimation(.easeInOut(duration: 0.4)) { appState = .intro }
                })
            }
        }
        .onAppear { checkState() }
        .onChange(of: auth.user) { _, user in
            if user == nil && appState == .home {
                UserDefaults.standard.set(false, forKey: "formAI_hasCompletedOnboarding")
                withAnimation { appState = .intro }
            }
        }
    }

    private func checkState() {
        if auth.user != nil || hasCompletedOnboarding {
            appState = .home
        } else {
            appState = .intro
        }
    }
}

// MARK: - Launch Loading View

struct LaunchLoadingView: View {
    let onComplete: () -> Void

    private let messages: [(emoji: String, text: String)] = [
        ("🏋️", "Getting your coaching ready..."),
        ("🔬", "Loading exercise library..."),
        ("🧠", "Warming up the AI coach..."),
        ("📊", "Setting up your analytics..."),
        ("✅", "Almost ready..."),
    ]

    @State private var messageIndex = 0
    @State private var opacity = 1.0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Text("Form AI")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.primary)

                VStack(spacing: 12) {
                    Text(messages[messageIndex].emoji)
                        .font(.system(size: 40))
                        .opacity(opacity)

                    Text(messages[messageIndex].text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .opacity(opacity)
                        .animation(.easeInOut(duration: 0.3), value: messageIndex)
                }
                .frame(height: 100)

                ProgressView()
                    .tint(Theme.primary)
                    .scaleEffect(1.2)

                Spacer()
            }
        }
        .task {
            let interval: UInt64 = 1_400_000_000
            for i in 1..<messages.count {
                try? await Task.sleep(nanoseconds: interval)
                withAnimation(.easeInOut(duration: 0.3)) { opacity = 0 }
                try? await Task.sleep(nanoseconds: 300_000_000)
                messageIndex = i
                withAnimation(.easeInOut(duration: 0.3)) { opacity = 1 }
            }
            try? await Task.sleep(nanoseconds: interval)
            onComplete()
        }
    }
}

#Preview { ContentView() }
