import XCTest
import PokerCore

private func drill(
    id: String = "fixture", hole: String = "Ks Qs", flop: String = "Ah 8d 2c",
    pot: Double = 100, call: Double = 0,
    hero: Double = 400, opponent: Double = 400, aggressor: Bool = true
) -> PracticeScenario {
    PracticeScenario(
        id: id, holeCards: cards(hole), flop: cards(flop),
        betting: BettingState(pot: pot, amountToCall: call, heroStack: hero, opponentStack: opponent),
        isPreflopAggressor: aggressor
    )
}

final class PracticeViewModelTests: XCTestCase {
    func testDryKingQueenDrillGradesRealContinuationBetAfterSubmission() async throws {
        try await MainActor.run {
            let model = PracticeViewModel(scenarios: [drill()])
            XCTAssertTrue(model.canAnswer)
            XCTAssertNil(model.feedback)
            XCTAssertEqual(model.attemptCount, 0)
            model.submit(.bet)
            let result = try XCTUnwrap(model.feedback)
            XCTAssertTrue(result.isCorrect)
            XCTAssertEqual(result.scenarioID, "fixture")
            XCTAssertEqual(result.correctChoice, .bet)
            XCTAssertEqual(result.analysis.recommendation.action, .bet(amount: 33))
            XCTAssertEqual(result.analysis.recommendation.reason, .dryBoardContinuationBet)
            XCTAssertTrue(result.explanation.contains(result.analysis.recommendation.explanation))
            XCTAssertEqual(model.correctCount, 1)
            XCTAssertEqual(model.attemptCount, 1)
            XCTAssertFalse(model.canAnswer)
        }
    }

    func testWrongAnswerRetainsChosenActionAndDoesNotEarnPoint() async throws {
        try await MainActor.run {
            let model = PracticeViewModel(scenarios: [drill()])
            model.submit(.fold)
            let result = try XCTUnwrap(model.feedback)
            XCTAssertFalse(result.isCorrect)
            XCTAssertEqual(result.chosenChoice, .fold)
            XCTAssertEqual(result.correctChoice, .bet)
            XCTAssertEqual(model.correctCount, 0)
            XCTAssertEqual(model.attemptCount, 1)
        }
    }

    func testWetWeakHandGradesCheckDespitePreflopInitiative() async throws {
        try await MainActor.run {
            let model = PracticeViewModel(scenarios: [drill(hole: "Qs Jh", flop: "9h 8h 2c")])
            model.submit(.check)
            let result = try XCTUnwrap(model.feedback)
            XCTAssertTrue(result.isCorrect)
            XCTAssertEqual(result.analysis.texture.texture, .wetConnected)
            XCTAssertEqual(result.analysis.recommendation.reason, .checkWithoutValue)
        }
    }

    func testOpeningAllInIsBetAndSPRBoundaryRemainsStrict() async throws {
        try await MainActor.run {
            let short = PracticeViewModel(scenarios: [drill(
                hole: "Kc Qh", flop: "Kd 8s 2c", hero: 75, opponent: 75, aggressor: false
            )])
            short.submit(.bet)
            XCTAssertTrue(try XCTUnwrap(short.feedback).isCorrect)
            XCTAssertEqual(short.feedback?.analysis.recommendation.action, .allIn(amount: 75))
            let boundary = PracticeViewModel(scenarios: [drill(
                hole: "Kc Qh", flop: "Kd 8s 2c", hero: 100, opponent: 100, aggressor: false
            )])
            boundary.submit(.check)
            XCTAssertTrue(try XCTUnwrap(boundary.feedback).isCorrect)
            XCTAssertEqual(boundary.feedback?.analysis.recommendation.action, .check)
        }
    }

    func testExpensiveDrawUsesNextCardOddsToGradeFold() async throws {
        try await MainActor.run {
            let model = PracticeViewModel(scenarios: [drill(
                hole: "Kh Qh", flop: "Ah 9h 2c", pot: 150, call: 50,
                hero: 500, opponent: 450, aggressor: false
            )])
            model.submit(.fold)
            let result = try XCTUnwrap(model.feedback)
            XCTAssertTrue(result.isCorrect)
            XCTAssertEqual(result.analysis.recommendation.reason, .drawTooExpensive)
            XCTAssertEqual(result.analysis.outs.count, 9)
            XCTAssertEqual(try XCTUnwrap(result.analysis.decisionDrawProbability), 9.0 / 47, accuracy: 1e-12)
            XCTAssertEqual(result.analysis.approximateDrawProbability, 0.36)
        }
    }

    func testIllegalCheckOrNewBetFacingWagerGetsExplanatoryIncorrectFeedback() async throws {
        try await MainActor.run {
            for choice in [PracticeChoice.check, .bet] {
                let model = PracticeViewModel(scenarios: [drill(
                    hole: "Kh Qh", flop: "Ah 9h 2c", pot: 150, call: 50,
                    hero: 500, opponent: 450, aggressor: false
                )])
                model.submit(choice)
                let result = try XCTUnwrap(model.feedback)
                XCTAssertFalse(result.isCorrect)
                XCTAssertEqual(result.correctChoice, .fold)
                XCTAssertTrue(result.explanation.contains(result.analysis.recommendation.explanation))
                XCTAssertNotEqual(result.explanation, result.analysis.recommendation.explanation)
                XCTAssertEqual(model.attemptCount, 1)
            }
        }
    }

    func testRepeatedSubmissionCannotChangeFeedbackOrScore() async {
        await MainActor.run {
            let model = PracticeViewModel(scenarios: [drill()])
            model.submit(.fold)
            let firstResult = model.feedback
            model.submit(.bet)
            model.submit(.check)
            XCTAssertEqual(model.feedback, firstResult)
            XCTAssertEqual(model.correctCount, 0)
            XCTAssertEqual(model.attemptCount, 1)
        }
    }

    func testNextRequiresAnswerClearsFeedbackAndCyclesWithoutLosingScore() async {
        await MainActor.run {
            let model = PracticeViewModel(scenarios: [
                drill(id: "first"),
                drill(id: "second", hole: "Qs Jh", flop: "9h 8h 2c")
            ])
            model.nextScenario()
            XCTAssertEqual(model.currentScenario?.id, "first")
            XCTAssertEqual(model.scenarioNumber, 1)
            model.submit(.bet)
            model.nextScenario()
            XCTAssertEqual(model.currentScenario?.id, "second")
            XCTAssertEqual(model.scenarioNumber, 2)
            XCTAssertNil(model.feedback)
            XCTAssertTrue(model.canAnswer)
            model.submit(.bet)
            model.nextScenario()
            XCTAssertEqual(model.currentScenario?.id, "first")
            XCTAssertEqual(model.scenarioNumber, 1)
            XCTAssertEqual(model.correctCount, 1)
            XCTAssertEqual(model.attemptCount, 2)
            model.submit(.bet)
            XCTAssertEqual(model.correctCount, 2)
            XCTAssertEqual(model.attemptCount, 3)
        }
    }

    func testEmptyCatalogHasUnavailableStateAndCannotScore() async {
        await MainActor.run {
            let model = PracticeViewModel(scenarios: [])
            XCTAssertNil(model.currentScenario)
            XCTAssertNotNil(model.errorMessage)
            XCTAssertFalse(model.canAnswer)
            XCTAssertEqual(model.scenarioCount, 0)
            XCTAssertEqual(model.scenarioNumber, 0)
            model.submit(.bet)
            model.nextScenario()
            XCTAssertNil(model.feedback)
            XCTAssertEqual(model.attemptCount, 0)
        }
    }

    func testMalformedCardCountsAndDuplicatesCannotBecomeDrills() async {
        await MainActor.run {
            let malformed = [
                drill(hole: "Ks"), drill(hole: "Ks Qs Jh"),
                drill(flop: "Ah 8d"), drill(flop: "Ah 8d 2c 3c"),
                drill(hole: "Ks Ks"), drill(flop: "Ks 8d 2c")
            ]
            for scenario in malformed {
                let model = PracticeViewModel(scenarios: [scenario])
                XCTAssertNil(model.currentScenario)
                XCTAssertNotNil(model.errorMessage)
                XCTAssertFalse(model.canAnswer)
                model.submit(.bet)
                XCTAssertEqual(model.attemptCount, 0)
            }
        }
    }

    func testInvalidOrNonliveBettingStatesCannotBecomeDrills() async {
        await MainActor.run {
            let malformed = [
                drill(pot: 0), drill(pot: -.infinity), drill(pot: .nan),
                drill(pot: 10, call: 20), drill(hero: 0), drill(hero: -1),
                drill(hero: .infinity), drill(opponent: 0), drill(opponent: .nan)
            ]
            for scenario in malformed {
                let model = PracticeViewModel(scenarios: [scenario])
                XCTAssertNil(model.currentScenario)
                XCTAssertNotNil(model.errorMessage)
                XCTAssertFalse(model.canAnswer)
            }
        }
    }

    func testCallsRaisesAndFacingBetAllInsAreNotMislabeledAsBet() async throws {
        try await MainActor.run {
            let unsupported: [(PracticeScenario, PokerAction)] = [
                (drill(hole: "Qs Js", flop: "Kh Tc 3d", pot: 200, call: 25,
                       hero: 500, opponent: 475, aggressor: false), .call(amount: 25)),
                (drill(hole: "Kc Qh", flop: "Kd 8s 2c", call: 10,
                       hero: 500, opponent: 20, aggressor: false), .raise(to: 30)),
                (drill(hole: "Kc Qh", flop: "Kd 8s 2c", call: 50,
                       hero: 25, opponent: 400, aggressor: false), .allIn(amount: 25)),
                (drill(hole: "Kc Qh", flop: "Kd 8s 2c", pot: 200, call: 50,
                       hero: 100, opponent: 400, aggressor: false), .allIn(amount: 100))
            ]
            for (scenario, expectedAction) in unsupported {
                let analysis = try PostflopHeuristicEngine.analyze(
                    holeCards: scenario.holeCards, board: scenario.flop,
                    betting: scenario.betting, isPreflopAggressor: scenario.isPreflopAggressor
                )
                XCTAssertEqual(analysis.recommendation.action, expectedAction)
                let model = PracticeViewModel(scenarios: [scenario])
                XCTAssertNil(model.currentScenario)
                XCTAssertNotNil(model.errorMessage)
                model.submit(.bet)
                XCTAssertNil(model.feedback)
                XCTAssertEqual(model.attemptCount, 0)
            }
        }
    }

    func testInvalidNextScenarioClearsPreviousCardsAndFeedbackWithoutScoring() async {
        await MainActor.run {
            let model = PracticeViewModel(scenarios: [drill(), drill(id: "bad", hole: "Ks Ks")])
            model.submit(.bet)
            model.nextScenario()
            XCTAssertNil(model.currentScenario)
            XCTAssertNil(model.feedback)
            XCTAssertNotNil(model.errorMessage)
            XCTAssertFalse(model.canAnswer)
            XCTAssertEqual(model.correctCount, 1)
            XCTAssertEqual(model.attemptCount, 1)
            model.submit(.bet)
            XCTAssertEqual(model.attemptCount, 1)
        }
    }

    func testBuiltInCatalogUsesUniqueFaceCardsAndEveryDrillCanBeGraded() async throws {
        try await MainActor.run {
            let catalog = PracticeScenarioCatalog.faceCardDrills
            XCTAssertEqual(catalog.count, 10)
            XCTAssertEqual(Set(catalog.map(\.id)).count, catalog.count)
            XCTAssertEqual(catalog.first?.holeCards, cards("Ks Qs"))
            let expected: [PracticeChoice] = [.bet, .bet, .bet, .check, .check, .bet, .check, .fold, .bet, .fold]
            let model = PracticeViewModel(scenarios: catalog)
            for (index, scenario) in catalog.enumerated() {
                XCTAssertEqual(scenario.holeCards.count, 2)
                XCTAssertTrue(scenario.holeCards.allSatisfy { [.jack, .queen, .king].contains($0.rank) })
                XCTAssertEqual(try Deck.remaining(excluding: scenario.holeCards + scenario.flop).count, 47)
                XCTAssertEqual(model.currentScenario, scenario)
                XCTAssertEqual(model.scenarioNumber, index + 1)
                XCTAssertTrue(model.canAnswer)
                model.submit(expected[index])
                XCTAssertTrue(try XCTUnwrap(model.feedback).isCorrect)
                model.nextScenario()
            }
            XCTAssertEqual(model.correctCount, 10)
            XCTAssertEqual(model.attemptCount, 10)
            XCTAssertEqual(model.currentScenario?.id, catalog.first?.id)
        }
    }
}
