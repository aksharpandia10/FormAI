import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class FormAIOnboardingData: ObservableObject {
    @Published var name: String = ""
    @Published var gender: String = ""
    @Published var workoutsPerWeek: String = ""
    @Published var age: Int = 25
    @Published var heardFrom: String = ""
    @Published var triedOtherApps: String = ""
    @Published var hasTrainer: String = ""
    @Published var stoppingPoints: [String] = []
    @Published var goals: [String] = []

    func save() {
        UserDefaults.standard.set(name, forKey: "ob_name")
        UserDefaults.standard.set(gender, forKey: "ob_gender")
        UserDefaults.standard.set(workoutsPerWeek, forKey: "ob_workouts")
        UserDefaults.standard.set(age, forKey: "ob_age")
        UserDefaults.standard.set(hasTrainer, forKey: "ob_trainer")
        saveToFirestore()
    }

    private func saveToFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let data: [String: Any] = [
            "name": name,
            "gender": gender,
            "workoutsPerWeek": workoutsPerWeek,
            "age": age,
            "heardFrom": heardFrom,
            "triedOtherApps": triedOtherApps,
            "hasTrainer": hasTrainer,
            "stoppingPoints": stoppingPoints,
            "goals": goals,
            "completedAt": Date().timeIntervalSince1970
        ]
        Firestore.firestore()
            .collection("users").document(uid)
            .setData(["onboarding": data], merge: true)
    }

    var coachingContext: String {
        "Name: \(name). Gender: \(gender). Age: \(age). Trains \(workoutsPerWeek)/week. Has trainer: \(hasTrainer). Goals: \(goals.joined(separator: ", ")). Concerns: \(stoppingPoints.joined(separator: ", "))."
    }
}

struct FormAIOnboardingView: View {
    let onComplete: () -> Void
    var onBack: (() -> Void)? = nil
    var initialStep: Int = 0

    @StateObject private var data = FormAIOnboardingData()
    @State private var step = 0
    @State private var goingForward = true

    private let totalSteps = 9

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { step == 0 ? onBack?() : previous() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Theme.cardBackground)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.cardBackground).frame(height: 4)
                        Capsule()
                            .fill(Theme.primary)
                            .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(totalSteps), height: 4)
                            .animation(.easeInOut(duration: 0.3), value: step)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Group {
                    switch step {
                    case 0: genderStep
                    case 1: workoutsStep
                    case 2: birthYearStep
                    case 3: heardFromStep
                    case 4: triedAppsStep
                    case 5: trainerStep
                    case 6: stoppingStep
                    case 7: goalsStep
                    case 8: nameStep
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: goingForward ? .trailing : .leading),
                    removal: .move(edge: goingForward ? .leading : .trailing)
                ))
                .id(step)
            }
        }
        .onAppear { step = initialStep; AnalyticsService.onboardingStepViewed(step: initialStep, stepName: onboardingStepName(initialStep)) }
        .onChange(of: step) { oldStep, newStep in
            if newStep > oldStep {
                AnalyticsService.onboardingStepViewed(step: newStep, stepName: onboardingStepName(newStep))
            }
        }
    }

    private func onboardingStepName(_ s: Int) -> String {
        switch s {
        case 0: return "gender"
        case 1: return "training_frequency"
        case 2: return "age"
        case 3: return "heard_from"
        case 4: return "tried_apps"
        case 5: return "has_trainer"
        case 6: return "stopping_points"
        case 7: return "goals"
        case 8: return "name"
        default: return "unknown"
        }
    }

    private var nameStep: some View {
        NameStep(name: $data.name, onNext: {
            data.save()
            UserDefaults.standard.set(data.coachingContext, forKey: "ob_coachingContext")
            onComplete()
        })
    }

    private var genderStep: some View {
        OBStep(title: "What's your gender?", subtitle: "Helps calibrate your coaching feedback.",
               options: ["Male", "Female", "Non-binary", "Prefer not to say"]) { sel in
            data.gender = sel.first ?? ""
            AnalyticsService.onboardingAnswered(step: "gender", answer: data.gender)
            next()
        }
    }

    private var workoutsStep: some View {
        OBStep(title: "How often do you train?", subtitle: "Per week on average.",
               options: ["1-2x per week", "3-4x per week", "5-6x per week", "Every day"]) { sel in
            data.workoutsPerWeek = sel.first ?? ""
            AnalyticsService.onboardingAnswered(step: "training_frequency", answer: data.workoutsPerWeek)
            next()
        }
    }

    private var birthYearStep: some View {
        AgeStep(age: $data.age, onNext: {
            AnalyticsService.onboardingAnswered(step: "age", answer: "\(data.age)")
            next()
        })
    }

    private var heardFromStep: some View {
        OBStep(title: "How did you find us?", subtitle: "",
               options: ["TikTok / Instagram", "A friend", "App Store", "Google / YouTube", "Other"]) { sel in
            data.heardFrom = sel.first ?? ""
            AnalyticsService.onboardingAnswered(step: "heard_from", answer: data.heardFrom)
            next()
        }
    }

    private var triedAppsStep: some View {
        OBStep(title: "Tried other form checking apps?", subtitle: "",
               options: ["Yes, and loved it", "Yes, wasn't impressed", "No, first time"]) { sel in
            data.triedOtherApps = sel.first ?? ""
            AnalyticsService.onboardingAnswered(step: "tried_apps", answer: data.triedOtherApps)
            next()
        }
    }

    private var trainerStep: some View {
        OBStep(title: "Do you work with a trainer?", subtitle: "",
               options: ["Yes, currently", "Used to, not anymore", "Never had one"]) { sel in
            data.hasTrainer = sel.first ?? ""
            AnalyticsService.onboardingAnswered(step: "has_trainer", answer: data.hasTrainer)
            next()
        }
    }

    private var stoppingStep: some View {
        OBStep(title: "What's holding you back?", subtitle: "Select all that apply.",
               options: ["Fear of injury", "Not seeing progress", "Unsure if my form is right",
                         "Can't afford a trainer", "Training alone with no feedback"],
               multiSelect: true) { sel in
            data.stoppingPoints = sel
            AnalyticsService.onboardingAnswered(step: "stopping_points", answer: sel.joined(separator: ", "))
            next()
        }
    }

    private var goalsStep: some View {
        OBStep(title: "What do you want to accomplish?", subtitle: "Select all that apply.",
               options: ["Get stronger", "Build muscle", "Stay injury free", "Compete or perform",
                         "Improve my technique"],
               multiSelect: true) { sel in
            data.goals = sel
            AnalyticsService.onboardingAnswered(step: "goals", answer: sel.joined(separator: ", "))
            next()
        }
    }

    private func next() {
        goingForward = true
        withAnimation(.easeInOut(duration: 0.3)) { step = min(step + 1, totalSteps - 1) }
    }

    private func previous() {
        goingForward = false
        withAnimation(.easeInOut(duration: 0.3)) { step = max(step - 1, 0) }
    }
}

// MARK: - Name Step

struct NameStep: View {
    @Binding var name: String
    let onNext: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Let's make this yours")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("This personalizes your coaching from the very first rep.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 48)

            TextField("Your name", text: $name)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { if !name.trimmingCharacters(in: .whitespaces).isEmpty { onNext() } }
                .padding(.horizontal, 24)

            Spacer()

            Button {
                name = name.trimmingCharacters(in: .whitespaces)
                onNext()
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.textSecondary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.primary.opacity(0.3) : Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear { focused = true }
    }
}

// MARK: - OBStep

struct OBStep: View {
    let title: String
    let subtitle: String
    let options: [String]
    var multiSelect: Bool = false
    let onNext: ([String]) -> Void

    @State private var selected: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 24)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            if multiSelect {
                                if selected.contains(option) { selected.removeAll { $0 == option } }
                                else { selected.append(option) }
                            } else {
                                onNext([option])
                            }
                        } label: {
                            HStack {
                                Text(option)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if multiSelect {
                                    Image(systemName: selected.contains(option) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(option) ? Theme.primary : Theme.textSecondary.opacity(0.4))
                                        .font(.system(size: 20))
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .padding(18)
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(selected.contains(option) ? Theme.primary : Color.clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            if multiSelect {
                Button { onNext(selected) } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(selected.isEmpty ? Theme.primary.opacity(0.4) : Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(selected.isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Age Step

struct AgeStep: View {
    @Binding var age: Int
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("How old are you?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Helps personalize coaching to your stage of life.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            Spacer()

            Picker("", selection: $age) {
                ForEach(16...80, id: \.self) { a in
                    Text("\(a)")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .tag(a)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity, maxHeight: 200)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.textSecondary.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}
