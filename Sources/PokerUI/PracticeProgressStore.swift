import Foundation
import PokerCore

/// Stores topic accuracy separately from the live table and current quiz score.
@MainActor final class PracticeProgressStore {
    static let key = "riverline.practice-learning.v1"
    private let defaults: UserDefaults

    private struct Snapshot: Codable {
        let version: Int
        let progress: PracticeLearningProgress
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func load() -> PracticeLearningProgress {
        guard let data = defaults.data(forKey: Self.key),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.version == 1, snapshot.progress.isValid else {
            return PracticeLearningProgress()
        }
        return snapshot.progress
    }

    func save(_ progress: PracticeLearningProgress) {
        guard progress.isValid,
              let data = try? JSONEncoder().encode(Snapshot(version: 1, progress: progress)) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
