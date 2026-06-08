import Foundation
import UIKit

struct FormCheckEntry: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    let exerciseId: String
    let exerciseName: String
    let score: Int
    let didWell: [String]
    let improve: [String]
    let summary: String
    let timestamp: Double

    var date: Date { Date(timeIntervalSince1970: timestamp) }

    init(exerciseId: String, exerciseName: String, score: Int,
         didWell: [String], improve: [String], summary: String) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.score = score
        self.didWell = didWell
        self.improve = improve
        self.summary = summary
        self.timestamp = Date().timeIntervalSince1970
    }
}

struct FormCheckResult {
    let exercise: Exercise
    let entry: FormCheckEntry
    var frames: [UIImage] = []
}
