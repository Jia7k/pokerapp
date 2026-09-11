import XCTest
@testable import PokerCore

final class PracticeScenarioGeneratorTests: XCTestCase {
    func testSeedReplaysSuccessiveDealsAndDifferentSeedsDiverge() throws {
        var first = PracticeScenarioGenerator(seed: 16)
        var replay = PracticeScenarioGenerator(seed: 16)
        var other = PracticeScenarioGenerator(seed: 91)
        var differentDeals = 0
        for _ in 0..<24 {
            let generated = try first.next()
            let repeated = try replay.next()
            let different = try other.next()
            XCTAssertEqual(generated.scenario, repeated.scenario)
            XCTAssertEqual(generated.analysis, repeated.analysis)
            XCTAssertEqual(generated.choice, repeated.choice)
            if generated.scenario.holeCards + generated.scenario.flop !=
                different.scenario.holeCards + different.scenario.flop {
                differentDeals += 1
            }
        }
        XCTAssertGreaterThan(differentDeals, 20)
    }

    func testGeneratedBatchUsesLegalFaceCardDealsVariedSituationsAndRealEngineAnswers() throws {
        var generator = PracticeScenarioGenerator(seed: 16)
        var choices: Set<PracticeChoice> = []
        var textures: Set<BoardTexture> = []
        var initiatives: Set<Bool> = []
        var signatures: Set<[Card]> = []
        var sawShortStack = false
        var sawExactSPRBoundary = false
        var sawDeepStack = false
        var sawFacingBet = false

        for _ in 0..<160 {
            let prepared = try generator.next()
            let scenario = prepared.scenario
            XCTAssertEqual(scenario.holeCards.count, 2)
            XCTAssertEqual(scenario.flop.count, 3)
            XCTAssertTrue(scenario.holeCards.allSatisfy { [.jack, .queen, .king].contains($0.rank) })
            XCTAssertEqual(try Deck.remaining(excluding: scenario.holeCards + scenario.flop).count, 47)
            XCTAssertNoThrow(try scenario.betting.validate())
            XCTAssertGreaterThan(scenario.betting.pot, 0)
            XCTAssertGreaterThan(scenario.betting.effectiveStack, 0)
            let expected = try PostflopHeuristicEngine.analyze(
                holeCards: scenario.holeCards, board: scenario.flop,
                betting: scenario.betting, isPreflopAggressor: scenario.isPreflopAggressor
            )
            XCTAssertEqual(prepared.analysis, expected)
            switch (expected.recommendation.action, scenario.betting.amountToCall == 0) {
            case (.bet, true), (.allIn, true): XCTAssertEqual(prepared.choice, .bet)
            case (.check, true): XCTAssertEqual(prepared.choice, .check)
            case (.fold, false): XCTAssertEqual(prepared.choice, .fold)
            default: XCTFail("Generated an answer that Bet / Check / Fold cannot represent")
            }
            let spr = try XCTUnwrap(scenario.betting.stackToPotRatio)
            sawShortStack = sawShortStack || spr < 1
            sawExactSPRBoundary = sawExactSPRBoundary || spr == 1
            sawDeepStack = sawDeepStack || spr >= 4
            sawFacingBet = sawFacingBet || scenario.betting.amountToCall > 0
            choices.insert(prepared.choice)
            textures.insert(expected.texture.texture)
            initiatives.insert(scenario.isPreflopAggressor)
            signatures.insert(scenario.holeCards.sorted() + scenario.flop.sorted())
        }
        XCTAssertEqual(choices, [.bet, .check, .fold])
        XCTAssertEqual(textures, [.dryRainbow, .wetConnected, .monotone])
        XCTAssertEqual(initiatives, [true, false])
        XCTAssertTrue(sawShortStack)
        XCTAssertTrue(sawExactSPRBoundary)
        XCTAssertTrue(sawDeepStack)
        XCTAssertTrue(sawFacingBet)
        XCTAssertGreaterThan(signatures.count, 150)
    }

    func testCheckedToFallbackKeepsFreshCardsAndReevaluatesTheChangedWager() throws {
        let facingCall = PracticeScenario(
            id: "fresh-deal", holeCards: cards("Qs Js"), flop: cards("Kh Tc 3d"),
            betting: BettingState(pot: 200, amountToCall: 25, heroStack: 500, opponentStack: 475),
            isPreflopAggressor: false
        )
        let original = try PostflopHeuristicEngine.analyze(
            holeCards: facingCall.holeCards, board: facingCall.flop, betting: facingCall.betting,
            isPreflopAggressor: facingCall.isPreflopAggressor
        )
        XCTAssertEqual(original.recommendation.action, .call(amount: 25))
        let fallback = try PracticeScenarioGenerator.checkedToFallback(from: facingCall)
        XCTAssertEqual(fallback.scenario.holeCards, cards("Qs Js"))
        XCTAssertEqual(fallback.scenario.flop, cards("Kh Tc 3d"))
        XCTAssertEqual(fallback.scenario.id, "fresh-deal")
        XCTAssertEqual(fallback.scenario.betting.amountToCall, 0)
        XCTAssertEqual(fallback.choice, .check)
        XCTAssertEqual(fallback.analysis.recommendation.action, .check)
        XCTAssertNil(fallback.analysis.decisionDrawProbability)
        XCTAssertGreaterThan(fallback.scenario.betting.pot, 0)
        XCTAssertGreaterThan(fallback.scenario.betting.effectiveStack, 0)
    }

    func testUnlimitedModelAdvancesBeyondCatalogWithoutWrappingOrRetainingAnswers() async throws {
        try await MainActor.run {
            let model = PracticeViewModel(seed: 16)
            var deals: Set<[Card]> = []
            var ids: Set<String> = []
            XCTAssertNil(model.scenarioCount)
            for number in 1...25 {
                let scenario = try XCTUnwrap(model.currentScenario)
                XCTAssertEqual(model.scenarioNumber, number)
                XCTAssertTrue(model.canAnswer)
                XCTAssertNil(model.feedback)
                XCTAssertNil(model.errorMessage)
                deals.insert(scenario.holeCards.sorted() + scenario.flop.sorted())
                ids.insert(scenario.id)
                model.submit(.bet)
                let result = try XCTUnwrap(model.feedback)
                let actual = try PostflopHeuristicEngine.analyze(
                    holeCards: scenario.holeCards, board: scenario.flop,
                    betting: scenario.betting, isPreflopAggressor: scenario.isPreflopAggressor
                )
                XCTAssertEqual(result.analysis, actual)
                XCTAssertEqual(result.scenarioID, scenario.id)
                XCTAssertEqual(result.isCorrect, result.correctChoice == .bet)
                model.nextScenario()
            }
            XCTAssertEqual(model.scenarioNumber, 26)
            XCTAssertEqual(model.attemptCount, 25)
            XCTAssertEqual(ids.count, 25)
            XCTAssertGreaterThan(deals.count, 20)
        }
    }

    func testSeededModelsReplayTheGeneratorAcrossNextCalls() async throws {
        try await MainActor.run {
            let first = PracticeViewModel(seed: 16)
            let replay = PracticeViewModel(seed: 16)
            var generator = PracticeScenarioGenerator(seed: 16)
            for _ in 0..<12 {
                let prepared = try generator.next()
                XCTAssertEqual(first.currentScenario, replay.currentScenario)
                XCTAssertEqual(first.currentScenario, prepared.scenario)
                first.submit(.check)
                replay.submit(.check)
                XCTAssertEqual(first.feedback, replay.feedback)
                XCTAssertEqual(first.feedback?.analysis, prepared.analysis)
                first.nextScenario()
                replay.nextScenario()
            }
        }
    }

    func testGeneratedNextRequiresOneAnswerAndRepeatedTapsDoNotChangeScore() async throws {
        try await MainActor.run {
            let model = PracticeViewModel(seed: 16)
            let initial = try XCTUnwrap(model.currentScenario)
            model.nextScenario()
            XCTAssertEqual(model.currentScenario, initial)
            XCTAssertEqual(model.scenarioNumber, 1)
            model.submit(.bet)
            let result = try XCTUnwrap(model.feedback)
            let earned = model.correctCount
            model.submit(.fold)
            model.submit(.check)
            XCTAssertEqual(model.feedback, result)
            XCTAssertEqual(model.correctCount, earned)
            XCTAssertEqual(model.attemptCount, 1)
            model.nextScenario()
            XCTAssertEqual(model.scenarioNumber, 2)
            XCTAssertNotEqual(model.currentScenario, initial)
            XCTAssertNil(model.feedback)
            XCTAssertEqual(model.correctCount, earned)
        }
    }

    func testDefaultModelStartsAnUnlimitedLiveDrill() async {
        await MainActor.run {
            let model = PracticeViewModel()
            XCTAssertNil(model.scenarioCount)
            XCTAssertEqual(model.scenarioNumber, 1)
            XCTAssertTrue(model.canAnswer)
            XCTAssertNil(model.errorMessage)
        }
    }
}
