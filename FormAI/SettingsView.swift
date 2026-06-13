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
