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

    static func onboardingStepViewed(step: Int, stepName: String) {
        Analytics.logEvent("onboarding_step_viewed", parameters: ["step": step, "step_name": stepName])
    }

    static func exerciseOpened(id: String, name: String, source: String) {
        Analytics.logEvent("exercise_opened", parameters: [
            "exercise_id": id,
            "exercise_name": name,
            "source": source
        ])
    }

    static func categoryTapped(category: String) {
        Analytics.logEvent("category_tapped", parameters: ["category": category])
    }

    static func formCheckTapped(exerciseId: String, exerciseName: String) {
        Analytics.logEvent("form_check_tapped", parameters: [
            "exercise_id": exerciseId,
            "exercise_name": exerciseName
        ])
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

    static func searchStarted() {
        Analytics.logEvent("search_started", parameters: nil)
    }

    static func searchResultTapped(query: String, exerciseId: String, exerciseName: String) {
        Analytics.logEvent("search_result_tapped", parameters: [
            "query": query,
            "exercise_id": exerciseId,
            "exercise_name": exerciseName
        ])
    }

    static func onboardingAnswered(step: String, answer: String) {
        Analytics.logEvent("onboarding_answered", parameters: [
            "step": step,
            "answer": answer
        ])
    }

    static func paywallShown(source: String) {
        Analytics.logEvent("paywall_shown", parameters: ["source": source])
    }

    static func subscriptionPurchased(plan: String) {
        Analytics.logEvent("subscription_purchased", parameters: ["plan": plan])
    }
}
