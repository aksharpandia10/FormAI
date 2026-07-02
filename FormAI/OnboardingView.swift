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
        let defaults = UserDefaults.standard
        defaults.set(name, forKey: "ob_name")
        defaults.set(gender, forKey: "ob_gender")
        defaults.set(workoutsPerWeek, forKey: "ob_workouts")
        defaults.set(age, forKey: "ob_age")
        defaults.set(hasTrainer, forKey: "ob_trainer")
        defaults.set(heardFrom, forKey: "ob_heardFrom")
        defaults.set(triedOtherApps, forKey: "ob_triedOtherApps")
        defaults.set(stoppingPoints, forKey: "ob_stoppingPoints")
        defaults.set(goals, forKey: "ob_goals")
        defaults.set(Date().timeIntervalSince1970, forKey: "ob_completedAt")
    }

    static func uploadPendingDataIfNeeded() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "ob_completedAt") != nil else { return }
        let data: [String: Any] = [
            "name": defaults.string(forKey: "ob_name") ?? "",
            "gender": defaults.string(forKey: "ob_gender") ?? "",
            "workoutsPerWeek": defaults.string(forKey: "ob_workouts") ?? "",
            "age": defaults.integer(forKey: "ob_age"),
            "heardFrom": defaults.string(forKey: "ob_heardFrom") ?? "",
            "triedOtherApps": defaults.string(forKey: "ob_triedOtherApps") ?? "",
            "hasTrainer": defaults.string(forKey: "ob_trainer") ?? "",
            "stoppingPoints": defaults.stringArray(forKey: "ob_stoppingPoints") ?? [],
            "goals": defaults.stringArray(forKey: "ob_goals") ?? [],
            "completedAt": defaults.double(forKey: "ob_completedAt")
        ]
        try? await Firestore.firestore()
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

    private let totalSteps = 12

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
                    case 8: formTrendStep
                    case 9: nameStep
                    case 10: thankYouStep
                    case 11: generateStep
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
        case 8: return "form_trend"
        case 9: return "name"
        case 10: return "thank_you"
        case 11: return "generate"
        default: return "unknown"
        }
    }

    private var formTrendStep: some View {
        FormTrendStep(onNext: { next() })
    }

    private var nameStep: some View {
        NameStep(name: $data.name, onNext: { next() })
    }

    private var thankYouStep: some View {
        ThankYouStep(onNext: { next() })
    }

    private var generateStep: some View {
        GenerateStep(onNext: {
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

// MARK: - Form Trend Step

struct FormTrendStep: View {
    let onNext: () -> Void
    @State private var lineProgress: CGFloat = 0
    @State private var cardVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your form gets better\nevery session")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Consistent feedback is how great lifters are made.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 32)

            VStack(spacing: 0) {
                HStack {
                    Text("Form Score")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    HStack(spacing: 12) {
                        legendDot(color: Theme.primary, label: "With FormAI")
                        legendDot(color: Theme.textSecondary.opacity(0.5), label: "Without")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

                FormTrendChart(progress: lineProgress)
                    .frame(height: 180)
                    .padding(.horizontal, 12)

                HStack {
                    Text("Week 1")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("Week 12")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
            .opacity(cardVisible ? 1 : 0)
            .offset(y: cardVisible ? 0 : 20)

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
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { cardVisible = true }
            withAnimation(.easeInOut(duration: 1.6).delay(0.4)) { lineProgress = 1.0 }
        }
    }

    @ViewBuilder
    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

struct FormTrendChart: View {
    let progress: CGFloat

    private func improvedPath(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: 0, y: h * 0.72))
        p.addCurve(
            to: CGPoint(x: w, y: h * 0.08),
            control1: CGPoint(x: w * 0.3, y: h * 0.72),
            control2: CGPoint(x: w * 0.65, y: h * 0.08)
        )
        return p
    }

    private func stagnantPath(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: 0, y: h * 0.72))
        p.addCurve(
            to: CGPoint(x: w, y: h * 0.82),
            control1: CGPoint(x: w * 0.35, y: h * 0.55),
            control2: CGPoint(x: w * 0.65, y: h * 0.82)
        )
        return p
    }

    private func improvedFillPath(in rect: CGRect) -> Path {
        var p = improvedPath(in: rect)
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }

    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)

            ZStack {
                // Subtle horizontal grid lines
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Spacer()
                        Rectangle()
                            .fill(Theme.textSecondary.opacity(0.08))
                            .frame(height: 1)
                    }
                }

                // Fill under "improved" line
                improvedFillPath(in: rect)
                    .fill(
                        LinearGradient(
                            colors: [Theme.primary.opacity(0.18 * progress), Theme.primary.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Stagnant line (dashed gray)
                stagnantPath(in: rect)
                    .trim(from: 0, to: progress)
                    .stroke(
                        Theme.textSecondary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4])
                    )

                // Improved line
                improvedPath(in: rect)
                    .trim(from: 0, to: progress)
                    .stroke(Theme.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // Start dot
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 10, height: 10)
                    .position(x: 5, y: rect.height * 0.72)

                // End dot (fades in as line arrives)
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 10, height: 10)
                    .position(x: rect.width - 5, y: rect.height * 0.08)
                    .opacity(Double(max(0, (progress - 0.9) / 0.1)))
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

// MARK: - Thank You Step

struct ThankYouStep: View {
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle().fill(Theme.primary.opacity(0.07)).frame(width: 224, height: 224)
                Circle().fill(Theme.primary.opacity(0.12)).frame(width: 164, height: 164)
                Circle().fill(Theme.primary.opacity(0.2)).frame(width: 104, height: 104)
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.primary)
                    .symbolEffect(.bounce, value: appeared)
            }
            .scaleEffect(appeared ? 1 : 0.75)
            .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 40)

            VStack(spacing: 8) {
                Text("Thanks for sharing that!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Now let's build your personalized\ncoaching profile.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            Spacer().frame(height: 32)

            HStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 36, height: 36)
                    .background(Theme.primary.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Personalized to your goals")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Your answers tailor every coaching cue.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(16)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)

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
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Generate Step

struct GenerateStep: View {
    let onNext: () -> Void
    @State private var appeared = false
    @State private var badgeVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle().fill(Theme.primary.opacity(0.07)).frame(width: 224, height: 224)
                Circle().fill(Theme.primary.opacity(0.12)).frame(width: 164, height: 164)
                Circle().fill(Theme.primary.opacity(0.2)).frame(width: 104, height: 104)
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.primary)
                    .symbolEffect(.variableColor, value: appeared)
            }
            .scaleEffect(appeared ? 1 : 0.75)
            .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 32)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.green)
                Text("All done!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .opacity(badgeVisible ? 1 : 0)
            .padding(.bottom, 10)

            Text("Time to build your\nform profile!")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

            Spacer()

            Button(action: onNext) {
                Text("Build My Profile")
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
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.1)) { appeared = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) { badgeVisible = true }
        }
    }
}
