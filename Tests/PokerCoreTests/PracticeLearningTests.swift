import XCTest
import PokerCore

final class PracticeLearningTests: XCTestCase {
    func testNewLearnerGetsNoMistakeBonusAndResultsStayWithinTheirTopic() {
        var progress = PracticeLearningProgress()
        XCTAssertTrue(PracticeTopic.allCases.allSatisfy { progress.reviewWeight(for: $0) == 0 })
        progress.record(topic: .drawPrice, correct: false)
        progress.record(topic: .drawPrice, correct: true)
        progress.record(topic: .checking, correct: true)
        XCTAssertEqual(progress.statistics(for: .drawPrice), PracticeTopicStats(attempts: 2, correct: 1))
        XCTAssertEqual(progress.statistics(for: .checking), PracticeTopicStats(attempts: 1, correct: 1))
        XCTAssertEqual(progress.statistics(for: .shortStack).attempts, 0)
        XCTAssertGreaterThan(progress.reviewWeight(for: .drawPrice), 0)
        XCTAssertEqual(progress.reviewWeight(for: .checking), 0)
    }

    func testMasteringAMissedConceptRemovesItsExtraReviewWeight() {
        var progress = PracticeLearningProgress()
        progress.record(topic: .shortStack, correct: false)
        let missedWeight = progress.reviewWeight(for: .shortStack)
        XCTAssertGreaterThan(missedWeight, 0)
        for _ in 0..<9 { progress.record(topic: .shortStack, correct: true) }
        XCTAssertLessThan(progress.reviewWeight(for: .shortStack), missedWeight)
        XCTAssertEqual(progress.reviewWeight(for: .shortStack), 0)
    }

    func testWeakerConceptReceivesMoreReviewWeight() {
        let progress = PracticeLearningProgress(stats: [
            .drawPrice: PracticeTopicStats(attempts: 10, correct: 4),
            .valueBet: PracticeTopicStats(attempts: 10, correct: 8)
        ])
        XCTAssertGreaterThan(progress.reviewWeight(for: .drawPrice), progress.reviewWeight(for: .valueBet))
    }

    func testCountersAgeBeforeOverflowAndKeepAValidAccuracyRatio() {
        var progress = PracticeLearningProgress(stats: [
            .facingBet: PracticeTopicStats(attempts: 1_000_000, correct: 700_000)
        ])
        progress.record(topic: .facingBet, correct: true)
        let result = progress.statistics(for: .facingBet)
        XCTAssertTrue(progress.isValid)
        XCTAssertEqual(result.attempts, 500_001)
        XCTAssertEqual(result.correct, 350_001)
        XCTAssertEqual(Double(result.correct) / Double(result.attempts), 0.7, accuracy: 0.00001)
    }

    func testInvalidRestoredCountsAreRejectedAndCannotAffectSelection() {
        for stats in [
            PracticeTopicStats(attempts: -1, correct: 0),
            PracticeTopicStats(attempts: 2, correct: 3),
            PracticeTopicStats(attempts: 5, correct: -1),
            PracticeTopicStats(attempts: Int.max, correct: 0)
        ] {
            var progress = PracticeLearningProgress(stats: [.checking: stats])
            XCTAssertFalse(progress.isValid)
            XCTAssertEqual(progress.reviewWeight(for: .checking), 0)
            progress.record(topic: .checking, correct: true)
            XCTAssertEqual(progress.statistics(for: .checking), PracticeTopicStats(attempts: 1, correct: 1))
        }
    }
}
