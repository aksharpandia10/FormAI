import SwiftUI

struct ShareCardView: View {
    let entry: FormCheckEntry
    let exerciseName: String

    private var scoreColor: Color {
        if entry.score >= 80 { return Color(hex: "#22C55E") }
        if entry.score >= 60 { return Color(hex: "#F59E0B") }
        return Color(hex: "#EF4444")
    }

    private var scoreLabel: String {
        if entry.score >= 80 { return "Crushing it" }
        if entry.score >= 60 { return "Almost there" }
        return "Needs work"
    }

    var body: some View {
        ZStack {
            Color(hex: "#1B2B5E").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Form AI")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(exerciseName)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    // Score circle
                    ZStack {
                        Circle()
                            .fill(scoreColor.opacity(0.2))
                            .frame(width: 80, height: 80)
                        Circle()
                            .trim(from: 0, to: CGFloat(entry.score) / 100)
                            .stroke(scoreColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(entry.score)")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(scoreColor)
                            Text("/ 100")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .padding(.bottom, 20)

                Text(scoreLabel.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(scoreColor)
                    .kerning(1)
                    .padding(.bottom, 8)

                Text(entry.summary)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 20)

                // Did well
                if !entry.didWell.isEmpty {
                    feedbackSection(
                        title: "What I did well",
                        items: Array(entry.didWell.prefix(2)),
                        color: Color(hex: "#22C55E")
                    )
                    .padding(.bottom, 12)
                }

                // Improve
                if !entry.improve.isEmpty {
                    feedbackSection(
                        title: "To work on",
                        items: Array(entry.improve.prefix(2)),
                        color: Color(hex: "#F59E0B")
                    )
                }

                Spacer()

                // Footer
                HStack {
                    Text("Check your form at formai.app")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Image(systemName: "camera.viewfinder")
                        .foregroundStyle(.white.opacity(0.3))
                        .font(.system(size: 16))
                }
            }
            .padding(28)
        }
        .frame(width: 390, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    @ViewBuilder
    private func feedbackSection(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color.opacity(0.8))
                .kerning(0.5)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(item)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
func renderShareCard(entry: FormCheckEntry, exerciseName: String) -> UIImage? {
    let card = ShareCardView(entry: entry, exerciseName: exerciseName)
    let renderer = ImageRenderer(content: card)
    renderer.scale = 3
    return renderer.uiImage
}
