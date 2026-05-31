import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FormCheckHistoryService: ObservableObject {
    static let shared = FormCheckHistoryService()
    private let db = Firestore.firestore()
    private var cache: [FormCheckEntry] = []

    private init() {}

    private var uid: String? { Auth.auth().currentUser?.uid }

    func save(_ entry: FormCheckEntry) async throws {
        guard let uid else { return }
        let data = try Firestore.Encoder().encode(entry)
        try await db
            .collection("users").document(uid)
            .collection("formChecks")
            .document(entry.id)
            .setData(data)
        cache.insert(entry, at: 0)
    }

    func prefetch() async {
        guard cache.isEmpty else { return }
        cache = (try? await loadAllHistory()) ?? []
    }

    func loadHistory(for exerciseId: String) async throws -> [FormCheckEntry] {
        guard let uid else { return [] }
        let snap = try await db
            .collection("users").document(uid)
            .collection("formChecks")
            .whereField("exerciseId", isEqualTo: exerciseId)
            .order(by: "timestamp", descending: true)
            .limit(to: 20)
            .getDocuments()
        let entries = snap.documents.compactMap { try? $0.data(as: FormCheckEntry.self) }
        let others = cache.filter { $0.exerciseId != exerciseId }
        cache = entries + others
        return entries
    }

    func cachedHistory(for exerciseId: String) -> [FormCheckEntry] {
        cache.filter { $0.exerciseId == exerciseId }
    }

    func loadAllHistory() async throws -> [FormCheckEntry] {
        guard let uid else { return [] }
        let snap = try await db
            .collection("users").document(uid)
            .collection("formChecks")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments()
        return snap.documents.compactMap { try? $0.data(as: FormCheckEntry.self) }
    }
}
