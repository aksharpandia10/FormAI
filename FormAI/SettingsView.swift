import SwiftUI
import RevenueCatUI

struct FormAISettingsView: View {
    var onSignOut: (() -> Void)? = nil
    @StateObject private var auth = AuthService.shared
    @StateObject private var sub = SubscriptionService.shared
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showDeleteError = false
    @State private var isDeleting = false
    @State private var showCustomerCenter = false
    @State private var showPaywall = false
    @State private var showTerms = false
    @State private var showPrivacy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: Subscription
                sectionHeader("Subscription")
                cardGroup {
                    HStack {
                        Image(systemName: sub.isSubscribed ? "crown.fill" : "crown")
                            .foregroundStyle(sub.isSubscribed ? .yellow : Theme.textSecondary)
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sub.isSubscribed ? "Form AI Pro" : "Free Plan")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            if !sub.isSubscribed {
                                Text("Upgrade to check your form")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer()
                        if !sub.isSubscribed {
                            Button("Upgrade") { showPaywall = true }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Theme.primary)
                                .clipShape(Capsule())
                        }
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
                            Text("Marketing Screenshots")
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
        .sheet(isPresented: $showPaywall) {
            RevenueCatUI.PaywallView()
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
                        NavigationLink(value: MarketingTarget(exercise: exercise, score: 95)) {
                            marketingScorePill(95, color: Color(hex: "#22C55E"))
                        }
                        NavigationLink(value: MarketingTarget(exercise: exercise, score: 54)) {
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
        .navigationDestination(for: MarketingTarget.self) { target in
            FormCheckResultView(
                result: MarketingMock.result(for: target.exercise, score: target.score),
                skipSave: true,
                onDone: {}
            )
        }
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

struct MarketingTarget: Hashable {
    let exercise: Exercise
    let score: Int
}

enum MarketingMock {
    static func result(for exercise: Exercise, score: Int) -> FormCheckResult {
        let entry: FormCheckEntry
        if score >= 80 {
            entry = FormCheckEntry(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                score: score,
                didWell: [
                    "Strong, stable setup before every rep",
                    "Consistent path through the full range of motion",
                    "Great depth with no loss of tension at the bottom",
                    "Smooth, controlled tempo on the way down"
                ],
                improve: [
                    "Brace your core a touch harder at the top to fully lock in the position (frame 8)"
                ],
                summary: "Excellent control and textbook positioning throughout. Just one small refinement to make it perfect."
            )
        } else {
            entry = FormCheckEntry(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                score: score,
                didWell: [
                    "Solid starting stance and grip width",
                    "Kept a steady rhythm across your reps"
                ],
                improve: [
                    "Keep your spine neutral — you're rounding under load (frame 4)",
                    "Drive through your heels instead of shifting onto your toes (frame 6)",
                    "Control the descent; you're dropping too fast to stay tight (frame 9)"
                ],
                summary: "Some solid fundamentals here, but a few positioning issues are costing you tension and putting stress on the wrong areas."
            )
        }
        return FormCheckResult(exercise: exercise, entry: entry)
    }
}
#endif
