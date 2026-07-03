import SwiftUI
import RevenueCatUI

enum AppState {
    case loading
    case intro
    case onboarding
    case signIn
    case launching  // fun loading screen before home
    case paywall    // hard gate — must subscribe to proceed
    case home
}

struct ContentView: View {
    @StateObject private var auth = AuthService.shared
    @StateObject private var sub = SubscriptionService.shared
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
                        onboardingReturnStep = 11
                        withAnimation(.easeInOut(duration: 0.3)) { appState = .onboarding }
                    }
                )

            case .launching:
                LaunchLoadingView {
                    if sub.isSubscribed {
                        withAnimation(.easeInOut(duration: 0.5)) { appState = .home }
                    } else {
                        withAnimation(.easeInOut(duration: 0.5)) { appState = .paywall }
                    }
                }

            case .paywall:
                RevenueCatUI.PaywallView(displayCloseButton: false)
                    .onChange(of: sub.isSubscribed) { _, isSubscribed in
                        if isSubscribed {
                            withAnimation(.easeInOut(duration: 0.4)) { appState = .home }
                        }
                    }

            case .home:
                ExerciseHomeView(onSignOut: {
                    withAnimation(.easeInOut(duration: 0.4)) { appState = .intro }
                })
            }
        }
        .onAppear { checkState() }
        .onChange(of: auth.user) { _, user in
            if let user = user {
                Task { await sub.login(userId: user.uid) }
            } else {
                Task { await sub.logout() }
                if appState == .home {
                    UserDefaults.standard.set(false, forKey: "formAI_hasCompletedOnboarding")
                    withAnimation { appState = .intro }
                }
            }
        }
        .onChange(of: sub.isSubscribed) { _, isSubscribed in
            if !isSubscribed && appState == .home {
                withAnimation(.easeInOut(duration: 0.4)) { appState = .paywall }
            }
        }
    }

    private func checkState() {
        guard auth.user != nil || hasCompletedOnboarding else {
            appState = .intro
            return
        }
        if let uid = auth.user?.uid {
            Task {
                await sub.login(userId: uid)
                appState = sub.isSubscribed ? .home : .paywall
            }
        } else {
            appState = sub.isSubscribed ? .home : .paywall
        }
    }
}

// MARK: - Launch Loading View

struct LaunchLoadingView: View {
    let onComplete: () -> Void

    @State private var percentage = 0
    @State private var statusIndex = 0
    @State private var checkedItems: Set<Int> = []

    private let statusMessages = [
        "Personalizing coaching cues...",
        "Loading exercise library...",
        "Calibrating AI analysis...",
        "Building your profile...",
        "Almost ready..."
    ]
    private let checklistItems = [
        "Personalized coaching cues",
        "Exercise library",
        "AI form analysis",
        "Your profile"
    ]
    private let checkThresholds = [22, 48, 70, 88]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("\(percentage)%")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.08), value: percentage)

                Spacer().frame(height: 10)

                Text("We're building your profile")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 28)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.cardBackground)
                            .frame(height: 8)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Theme.primary, Theme.primary.opacity(0.55)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * CGFloat(percentage) / 100.0, height: 8)
                            .animation(.linear(duration: 0.08), value: percentage)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 24)

                Spacer().frame(height: 12)

                Text(statusMessages[statusIndex])
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .id(statusIndex)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))

                Spacer().frame(height: 36)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Setting up your experience")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .kerning(0.5)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    ForEach(Array(checklistItems.enumerated()), id: \.offset) { i, item in
                        HStack {
                            Text("· \(item)")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if checkedItems.contains(i) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.primary)
                                    .font(.system(size: 20))
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)

                        if i < checklistItems.count - 1 {
                            Divider().padding(.leading, 18)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .task { await runProgress() }
    }

    private func runProgress() async {
        let totalDuration: Double = 4.2
        let steps = 100
        let stepDuration = UInt64((totalDuration / Double(steps)) * 1_000_000_000)

        for i in 1...steps {
            try? await Task.sleep(nanoseconds: stepDuration)

            withAnimation { percentage = i }

            let newStatus: Int
            switch i {
            case ..<25: newStatus = 0
            case ..<50: newStatus = 1
            case ..<72: newStatus = 2
            case ..<90: newStatus = 3
            default:    newStatus = 4
            }
            if newStatus != statusIndex {
                withAnimation { statusIndex = newStatus }
            }

            for (j, threshold) in checkThresholds.enumerated() {
                if i >= threshold && !checkedItems.contains(j) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        checkedItems.insert(j)
                    }
                }
            }
        }

        try? await Task.sleep(nanoseconds: 500_000_000)
        onComplete()
    }
}

#Preview { ContentView() }
