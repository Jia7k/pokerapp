import Foundation
import XCTest
import PokerCore
@testable import PokerUI

final class PracticeProgressStoreTests: XCTestCase {
    private struct Fixture: Codable {
        let version: Int
        let progress: PracticeLearningProgress
    }

    func testSavedAccuracySurvivesReloadAndDoesNotReplaceTheLiveTable() async throws {
        try await MainActor.run {
            let suite = "riverline.test.practice.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let liveData = Data("existing live table".utf8)
            defaults.set(liveData, forKey: "riverline.session.v1")
            let store = PracticeProgressStore(defaults: defaults)
            var progress = store.load()
            progress.record(topic: .drawPrice, correct: false)
            progress.record(topic: .shortStack, correct: true)
            store.save(progress)
            XCTAssertEqual(PracticeProgressStore(defaults: defaults).load(), progress)
            XCTAssertEqual(defaults.data(forKey: "riverline.session.v1"), liveData)
        }
    }

    func testCorruptUnknownVersionAndInvalidCountsStartWithEmptyProgress() async throws {
        try await MainActor.run {
            let suite = "riverline.test.practice.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = PracticeProgressStore(defaults: defaults)
            let inputs = [
                Data("not json".utf8),
                try JSONEncoder().encode(Fixture(version: 99, progress: .init())),
                try JSONEncoder().encode(Fixture(version: 1, progress: .init(stats: [
                    .checking: PracticeTopicStats(attempts: 1, correct: 9)
                ])))
            ]
            for input in inputs {
                defaults.set(input, forKey: PracticeProgressStore.key)
                XCTAssertEqual(store.load(), PracticeLearningProgress())
            }
        }
    }

    func testInvalidSaveCannotOverwritePreviouslyValidProgress() async throws {
        try await MainActor.run {
            let suite = "riverline.test.practice.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = PracticeProgressStore(defaults: defaults)
            var progress = PracticeLearningProgress()
            progress.record(topic: .valueBet, correct: true)
            store.save(progress)
            store.save(PracticeLearningProgress(stats: [
                .valueBet: PracticeTopicStats(attempts: -1, correct: 0)
            ]))
            XCTAssertEqual(store.load(), progress)
        }
    }

    func testModelPersistsOneAnswerAndRestoresLearningWithAFreshSessionScore() async throws {
        try await MainActor.run {
            let suite = "riverline.test.practice.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = PracticeProgressStore(defaults: defaults)
            let model = PracticeViewModel(seed: 16, progress: store.load(), onProgressChange: { store.save($0) })
            let choice = try XCTUnwrap(model.availableChoices.first)
            model.submit(choice)
            let feedback = try XCTUnwrap(model.feedback)
            model.submit(choice)
            XCTAssertEqual(store.load().statistics(for: feedback.topic).attempts, 1)
            let restored = PracticeViewModel(seed: 16, progress: store.load())
            XCTAssertEqual(restored.learningProgress, model.learningProgress)
            XCTAssertEqual(restored.attemptCount, 0)
            XCTAssertEqual(restored.correctCount, 0)
        }
    }
}
