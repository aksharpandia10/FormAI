import SwiftUI
import AuthenticationServices

struct SaveProgressView: View {
    let onSignedIn: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void
    var isReturningUser: Bool = false

    @StateObject private var auth = AuthService.shared
    @State private var isLoadingGoogle = false
    @State private var isLoadingApple = false
    @State private var errorMessage: String?
    @State private var appleCoordinator: AppleSignInCoordinator?
    @State private var showTerms = false
    @State private var showPrivacy = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // Progress bar + back
                VStack(spacing: 12) {
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(Theme.cardBackground)
                                .clipShape(Circle())
                        }
                        Spacer()
                    }

                    if !isReturningUser {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.cardBackground).frame(height: 4)
                                Capsule().fill(Theme.primary).frame(width: geo.size.width * 0.85, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text(isReturningUser ? "Welcome back" : "Save your progress")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(isReturningUser ? "Sign in to pick up where you left off." : "Sign in to keep your plan and track progress across devices.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)

                Spacer()

                VStack(spacing: 12) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Apple Sign-In (custom button for size control)
                    Button { triggerAppleSignIn() } label: {
                        ZStack {
                            if isLoadingApple {
                                ProgressView().tint(.white)
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("Continue with Apple")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isLoadingApple || isLoadingGoogle)
                    .padding(.horizontal, 24)

                    // Google Sign-In
                    Button {
                        isLoadingGoogle = true
                        errorMessage = nil
                        Task {
                            do {
                                try await auth.signInWithGoogle()
                                isLoadingGoogle = false
                                AnalyticsService.signIn(method: "google")
                                onSignedIn()
                            } catch {
                                isLoadingGoogle = false
                                let nsError = error as NSError
                                // code 1 = user cancelled, don't show error
                                if nsError.code != 1 {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            if isLoadingGoogle {
                                ProgressView().tint(Theme.textPrimary)
                            } else {
                                HStack(spacing: 10) {
                                    GoogleGLogo(size: 18)
                                    Text("Continue with Google")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Theme.textSecondary.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .disabled(isLoadingApple || isLoadingGoogle)
                    .padding(.horizontal, 24)

                    // Legal agreement line
                    VStack(spacing: 2) {
                        Text("By continuing you agree to our")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 4) {
                            Button("Terms of Service") { showTerms = true }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                            Text("and")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                            Button("Privacy Policy") { showPrivacy = true }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                        }
                    }

                }
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showTerms) { TermsOfServiceView() }
        .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
    }

    // MARK: - Apple Sign-In

    private func triggerAppleSignIn() {
        isLoadingApple = true
        errorMessage = nil

        let nonce = AuthService.shared.generateAppleNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonce

        let coordinator = AppleSignInCoordinator { result in
            Task { @MainActor in
                switch result {
                case .success(let authorization):
                    do {
                        try await AuthService.shared.signInWithApple(authorization)
                        isLoadingApple = false
                        AnalyticsService.signIn(method: "apple")
                        onSignedIn()
                    } catch {
                        isLoadingApple = false
                        errorMessage = error.localizedDescription
                    }
                case .failure(let error):
                    isLoadingApple = false
                    let asError = error as? ASAuthorizationError
                    if asError?.code != .canceled {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        appleCoordinator = coordinator

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        controller.performRequests()
    }
}

// MARK: - Apple Coordinator

private class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    let onComplete: (Result<ASAuthorization, Error>) -> Void

    init(onComplete: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.onComplete = onComplete
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithAuthorization authorization: ASAuthorization) {
        onComplete(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithError error: Error) {
        onComplete(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - Google G Logo

struct GoogleGLogo: View {
    var size: CGFloat = 18

    private let blue   = Color(red: 66/255,  green: 133/255, blue: 244/255)
    private let red    = Color(red: 234/255, green: 67/255,  blue: 53/255)
    private let yellow = Color(red: 251/255, green: 188/255, blue: 5/255)
    private let green  = Color(red: 52/255,  green: 168/255, blue: 83/255)

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let center = CGPoint(x: w / 2, y: h / 2)
            let outerR = w * 0.47
            let innerR = w * 0.30
            let barH   = h * 0.155

            func ring(_ start: Double, _ end: Double) -> Path {
                var p = Path()
                p.addArc(center: center, radius: outerR,
                         startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
                p.addArc(center: center, radius: innerR,
                         startAngle: .degrees(end), endAngle: .degrees(start), clockwise: true)
                p.closeSubpath()
                return p
            }

            // Clockwise from the gap (~15°):
            context.fill(ring(15,  90),  with: .color(green))   // lower-right
            context.fill(ring(90,  210), with: .color(blue))    // bottom + left
            context.fill(ring(210, 315), with: .color(red))     // left + top-left
            context.fill(ring(315, 345), with: .color(yellow))  // top-right

            // Horizontal bar (blue) — fills the gap and extends right
            let barRect = CGRect(x: center.x - innerR * 0.15,
                                 y: center.y - barH,
                                 width: outerR + innerR * 0.15,
                                 height: barH * 2)
            context.fill(Path(barRect), with: .color(blue))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Compact Sign-In Sheet (returning users)

struct SignInSheet: View {
    let onSignedIn: () -> Void
    let onDismiss: () -> Void

    @StateObject private var auth = AuthService.shared
    @State private var isLoadingGoogle = false
    @State private var isLoadingApple = false
    @State private var errorMessage: String?
    @State private var appleCoordinator: AppleSignInCoordinator?
    @State private var showTerms = false
    @State private var showPrivacy = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Sign In")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)

                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Theme.cardBackground)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            .padding(.bottom, 24)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }

            // Apple
            Button { triggerAppleSignIn() } label: {
                ZStack {
                    if isLoadingApple { ProgressView().tint(.white) }
                    else {
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Continue with Apple")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLoadingApple || isLoadingGoogle)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Google
            Button {
                isLoadingGoogle = true; errorMessage = nil
                Task {
                    do {
                        try await auth.signInWithGoogle()
                        isLoadingGoogle = false
                        AnalyticsService.signIn(method: "google")
                        onSignedIn()
                    } catch {
                        isLoadingGoogle = false
                        let nsError = error as NSError
                        if nsError.code != 1 { errorMessage = error.localizedDescription }
                    }
                }
            } label: {
                ZStack {
                    if isLoadingGoogle { ProgressView().tint(Theme.textPrimary) }
                    else {
                        HStack(spacing: 10) {
                            GoogleGLogo(size: 18)
                            Text("Continue with Google")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.textSecondary.opacity(0.25), lineWidth: 1))
            }
            .disabled(isLoadingApple || isLoadingGoogle)
            .padding(.horizontal, 24)

            VStack(spacing: 2) {
                Text("By continuing you agree to our")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 4) {
                    Button("Terms of Service") { showTerms = true }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                    Text("and").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    Button("Privacy Policy") { showPrivacy = true }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .background(Theme.background)
        .sheet(isPresented: $showTerms) { TermsOfServiceView() }
        .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
    }

    private func triggerAppleSignIn() {
        isLoadingApple = true; errorMessage = nil
        let nonce = AuthService.shared.generateAppleNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonce
        let coordinator = AppleSignInCoordinator { result in
            Task { @MainActor in
                switch result {
                case .success(let auth):
                    do {
                        try await AuthService.shared.signInWithApple(auth)
                        isLoadingApple = false
                        AnalyticsService.signIn(method: "apple")
                        onSignedIn()
                    } catch {
                        isLoadingApple = false
                        errorMessage = error.localizedDescription
                    }
                case .failure(let error):
                    isLoadingApple = false
                    if (error as? ASAuthorizationError)?.code != .canceled {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        appleCoordinator = coordinator
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        controller.performRequests()
    }
}

#Preview {
    SaveProgressView(onSignedIn: {}, onSkip: {}, onBack: {})
}
