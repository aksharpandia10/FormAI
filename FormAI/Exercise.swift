import Foundation
import SwiftUI

enum ExerciseCategory: String, CaseIterable, Identifiable {
    case bigThree        = "The Big 3"
    case squatVariations = "Squat Variations"
    case deadliftVariations = "Deadlift Variations"
    case push            = "Push"
    case pull            = "Pull"
    case legs            = "Legs"
    case core            = "Core"
    case bodyweight      = "Bodyweight"

    var id: String { rawValue }

    var imageName: String {
        switch self {
        case .bigThree:           return "cat_big_three"
        case .squatVariations:    return "cat_squat_variations"
        case .deadliftVariations: return "cat_deadlift_variations"
        case .push:               return "cat_push"
        case .pull:               return "cat_pull"
        case .legs:               return "cat_legs"
        case .core:               return "cat_core"
        case .bodyweight:         return "cat_bodyweight"
        }
    }
}

enum Difficulty: String {
    case beginner     = "Beginner"
    case intermediate = "Intermediate"
    case advanced     = "Advanced"

    var color: Color {
        switch self {
        case .beginner:     return .green
        case .intermediate: return .orange
        case .advanced:     return .red
        }
    }
}

enum CameraAngle: String {
    case front  = "Front"
    case side   = "Side"
    case either = "Either"
}

struct Exercise: Identifiable {
    let id: String
    let name: String
    let category: ExerciseCategory
    let muscleGroups: [String]
    let equipment: String
    let difficulty: Difficulty
    let description: String
    let instructions: [String]
    let cameraAngle: CameraAngle
    var searchTerms: [String] = []
    var imageName: String = ""
}
