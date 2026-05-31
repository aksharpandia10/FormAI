import FirebaseAnalytics

enum AnalyticsService {
    static func onboardingCompleted() {
        Analytics.logEvent("onboarding_completed", parameters: nil)
    }

    static func signIn(method: String) {
        Analytics.logEvent("sign_in", parameters: ["method": method])
    }

    static func signInSkipped() {
        Analytics.logEvent("sign_in_skipped", parameters: nil)
    }

    static func exerciseOpened(id: String, name: String) {
        Analytics.logEvent("exercise_opened", parameters: ["exercise_id": id, "exercise_name": name])
    }

    static func formCheckStarted(exerciseId: String, exerciseName: String) {
        Analytics.logEvent("form_check_started", parameters: ["exercise_id": exerciseId, "exercise_name": exerciseName])
    }

    static func formCheckCompleted(exerciseId: String, exerciseName: String, score: Int) {
        Analytics.logEvent("form_check_completed", parameters: [
            "exercise_id": exerciseId,
            "exercise_name": exerciseName,
            "score": score
        ])
    }

    static func paywallShown(source: String) {
        Analytics.logEvent("paywall_shown", parameters: ["source": source])
    }

    static func subscriptionPurchased(plan: String) {
        Analytics.logEvent("subscription_purchased", parameters: ["plan": plan])
    }
}
