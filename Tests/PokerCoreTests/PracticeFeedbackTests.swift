import XCTest
import PokerCore

private func feedbackDrill(
    hole: String = "Ks Qs", flop: String = "Ah 8d 2c",
    pot: Double = 100, call: Double = 0, hero: Double = 400, opponent: Double = 400,
    aggressor: Bool = true, topic: PracticeTopic? = nil
) -> PracticeScenario {
    PracticeScenario(
        id: "feedback", holeCards: cards(hole), flop: cards(flop),
        betting: BettingState(pot: pot, amountToCall: call, heroStack: hero, opponentStack: opponent),
        isPreflopAggressor: aggressor, topic: topic
    )
}

final class PracticeFeedbackTests: XCTestCase {
    func testCheckedToChoicesExcludeFoldAndOmitUncoveredMinimumBet() async {
        await MainActor.run {
            let model = PracticeViewModel(scenarios: [feedbackDrill()])
            XCTAssertEqual(model.availableChoices, [.check, .bet])
            model.submit(.fold)
            XCTAssertEqual(model.attemptCount, 0)
            XCTAssertNil(model.feedback)
            let uncovered = PracticeViewModel(scenarios: [feedbackDrill(opponent: 5)])
            XCTAssertEqual(uncovered.availableChoices, [.check])
            uncovered.submit(.bet)
            XCTAssertNil(uncovered.feedback)
            uncovered.submit(.check)
            XCTAssertEqual(uncovered.correctCount, 1)
        }
    }

    func testRaiseChoicesRespectCoveredMinimumAndShortHeroAllIn() async {
        await MainActor.run {
            let standard = PracticeViewModel(scenarios: [feedbackDrill(call: 20)])
            XCTAssertEqual(standard.availableChoices, [.fold, .call, .raise])
            let opponentShort = PracticeViewModel(scenarios: [feedbackDrill(call: 20, hero: 100, opponent: 5)])
            XCTAssertEqual(opponentShort.availableChoices, [.fold, .call])
            let heroShort = PracticeViewModel(scenarios: [feedbackDrill(call: 20, hero: 25, opponent: 100)])
            XCTAssertEqual(heroShort.availableChoices, [.fold, .call, .raise])
            let allInCall = PracticeViewModel(scenarios: [feedbackDrill(call: 20, hero: 15, opponent: 100)])
            XCTAssertEqual(allInCall.availableChoices, [.fold, .call])
            let opponentAllIn = PracticeViewModel(scenarios: [feedbackDrill(call: 20, hero: 100, opponent: 0)])
            XCTAssertEqual(opponentAllIn.availableChoices, [.fold, .call])
        }
    }

    func testTopPairFeedbackShowsEffectiveStackSPRandActualCommitment() async throws {
        try await MainActor.run {
            let model = PracticeViewModel(scenarios: [feedbackDrill(
                hole: "Kc Qh", flop: "Kd 8s 2c", hero: 75, opponent: 400, aggressor: false
            )])
            model.submit(.bet)
            let result = try XCTUnwrap(model.feedback)
            XCTAssertEqual(result.topic, .shortStack)
            XCTAssertTrue(result.explanation.contains("Top pair"))
            XCTAssertTrue(result.explanation.contains("75/100 = 0.75"))
            XCTAssertTrue(result.explanation.contains("all in 75"))
            XCTAssertLessThanOrEqual(result.explanation.count, 250)
        }
    }

    func testOverpairIsDistinguishedFromTopPairInNumericalFeedback() async throws {
        try await MainActor.run {
            let model = PracticeViewModel(scenarios: [feedbackDrill(
                hole: "Qs Qh", flop: "Jd 8s 2c", hero: 75, opponent: 400, aggressor: false
            )])
            model.submit(.bet)
            XCTAssertTrue(try XCTUnwrap(model.feedback).explanation.contains("Overpair"))
        }
    }

    func testShortStackFeedbackDoesNotRoundBelowOneSPRIntoTheOppositeBoundary() async throws {
        try await MainActor.run {
            for stack in [99.9, 100.0.nextDown] {
                let model = PracticeViewModel(scenarios: [feedbackDrill(
                    hole: "Kc Qh", flop: "Kd 8s 2c", hero: stack, opponent: 400, aggressor: false
                )])
                model.submit(.bet)
                let text = try XCTUnwrap(model.feedback).explanation
                XCTAssertTrue(text.contains("0.999"))
                XCTAssertTrue(text.contains("< 1"))
                XCTAssertFalse(text.contains("= 1 (< 1)"))
                XCTAssertFalse(text.contains("100/100"))
                XCTAssertLessThanOrEqual(text.count, 250)
            }
        }
    }

    func testValueBetFeedbackNamesMadeHandAndActualAmountAndPercentage() async throws {
        try await MainActor.run {
            let model = PracticeViewModel(scenarios: [feedbackDrill(hole: "Kh Qd", flop: "Js Th 9c")])
            model.submit(.bet)
            let result = try XCTUnwrap(model.feedback)
            XCTAssertEqual(result.topic, .valueBet)
            XCTAssertTrue(result.explanation.contains("Straight"))
            XCTAssertTrue(result.explanation.contains("66"))
            XCTAssertTrue(result.explanation.contains("66%"))
        }
    }

    func testNormalFlopDrawFeedbackExplainsOneCardCompletionAndPotOdds() async throws {
        try await MainActor.run {
            let model = PracticeViewModel(scenarios: [feedbackDrill(
                hole: "Kh Qh", flop: "Ah 9h 2c", pot: 150, call: 50,
                hero: 500, opponent: 450, aggressor: false
            )])
            model.submit(.fold)
            let result = try XCTUnwrap(model.feedback)
            XCTAssertEqual(result.topic, .drawPrice)
            XCTAssertTrue(result.explanation.contains("9/47 = 19.1%"))
            XCTAssertTrue(result.explanation.contains("next-card completion"))
            XCTAssertTrue(result.explanation.contains("50/(150 + 50) = 25%"))
            XCTAssertFalse(result.explanation.contains("36%"))
            XCTAssertLessThanOrEqual(result.explanation.count, 250)
        }
    }

    func testClosingCallFeedbackLabelsRuleOfFourAndUsesContestablePot() async throws {
        try await MainActor.run {
            let model = PracticeViewModel(scenarios: [feedbackDrill(
                hole: "Kh Qh", flop: "Ah 9h 2c", pot: 150, call: 100,
                hero: 50, opponent: 450, aggressor: false
            )])
            model.submit(.call)
            let result = try XCTUnwrap(model.feedback)
            XCTAssertTrue(result.isCorrect)
            XCTAssertEqual(result.analysis.recommendation.action, .allIn(amount: 50))
            XCTAssertTrue(result.explanation.contains("Rule of 4"))
            XCTAssertTrue(result.explanation.contains("≈ 36%"))
            XCTAssertTrue(result.explanation.contains("50/(100 + 50) = 33.3%"))
            XCTAssertFalse(result.explanation.contains("9/47"))
            XCTAssertTrue(result.explanation.contains("completion"))
            XCTAssertTrue(result.explanation.contains("Call all in 50"))
        }
    }

    func testTopicProgressUpdatesOnceAfterValidAnswerAndCallsPersistence() async throws {
        try await MainActor.run {
            var prior = PracticeLearningProgress()
            prior.record(topic: .checking, correct: true)
            var saved: [PracticeLearningProgress] = []
            let model = PracticeViewModel(
                scenarios: [feedbackDrill(topic: .continuationBet)], progress: prior,
                onProgressChange: { saved.append($0) }
            )
            XCTAssertEqual(model.learningProgress.statistics(for: .checking).attempts, 1)
            XCTAssertEqual(model.attemptCount, 0)
            XCTAssertTrue(saved.isEmpty)
            model.submit(.fold)
            XCTAssertTrue(saved.isEmpty)
            model.submit(.check)
            XCTAssertEqual(try XCTUnwrap(model.feedback).topic, .continuationBet)
            XCTAssertEqual(model.learningProgress.statistics(for: .continuationBet).attempts, 1)
            XCTAssertEqual(model.learningProgress.statistics(for: .continuationBet).correct, 0)
            XCTAssertEqual(saved.count, 1)
            XCTAssertEqual(saved.first, model.learningProgress)
            model.submit(.bet)
            XCTAssertEqual(saved.count, 1)
            model.nextScenario()
            model.submit(.bet)
            XCTAssertEqual(model.learningProgress.statistics(for: .continuationBet).attempts, 2)
            XCTAssertEqual(model.learningProgress.statistics(for: .continuationBet).correct, 1)
            XCTAssertEqual(saved.count, 2)
        }
    }

    func testInvalidProgressNormalizesAndUnavailableDrillCannotRecord() async {
        await MainActor.run {
            let invalid = PracticeLearningProgress(stats: [.checking: .init(attempts: 1, correct: 2)])
            var callbackCount = 0
            let model = PracticeViewModel(scenarios: [], progress: invalid) { _ in callbackCount += 1 }
            XCTAssertTrue(model.learningProgress.isValid)
            XCTAssertEqual(model.learningProgress, .init())
            XCTAssertEqual(model.availableChoices, [])
            model.submit(.check)
            XCTAssertEqual(callbackCount, 0)
        }
    }
}
