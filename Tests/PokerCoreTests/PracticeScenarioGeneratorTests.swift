import XCTest
@testable import PokerCore

final class PracticeScenarioGeneratorTests: XCTestCase {
    func testSeedReplaysCoverageAndDifferentSeedsDiverge() throws {
        var first = PracticeScenarioGenerator(seed: 16)
        var replay = PracticeScenarioGenerator(seed: 16)
        var other = PracticeScenarioGenerator(seed: 91)
        var differences = 0
        for _ in 0..<24 {
            let a = try first.next()
            let b = try replay.next()
            let c = try other.next()
            XCTAssertEqual(a.scenario, b.scenario)
            XCTAssertEqual(a.analysis, b.analysis)
            XCTAssertEqual(a.choice, b.choice)
            if a.scenario.holeCards + a.scenario.flop != c.scenario.holeCards + c.scenario.flop { differences += 1 }
        }
        XCTAssertGreaterThan(differences, 20)
    }

    func testEachUnweightedRoundCoversEveryConceptExactlyOnce() throws {
        var generator = PracticeScenarioGenerator(seed: 16)
        var orders: Set<[PracticeTopic]> = []
        for _ in 0..<8 {
            var topics: [PracticeTopic] = []
            for _ in PracticeTopic.allCases {
                let prepared = try generator.next()
                topics.append(prepared.topic)
                XCTAssertEqual(prepared.scenario.topic, prepared.topic)
                XCTAssertEqual(PreparedPracticeScenario.inferTopic(scenario: prepared.scenario, analysis: prepared.analysis), prepared.topic)
            }
            XCTAssertEqual(Set(topics), Set(PracticeTopic.allCases))
            orders.insert(topics)
        }
        XCTAssertGreaterThan(orders.count, 4)
    }

    func testMissedTopicGetsThreeBonusSlotsWithoutLosingCoverage() throws {
        let progress = PracticeLearningProgress(stats: [.drawPrice: .init(attempts: 8, correct: 0)])
        var generator = PracticeScenarioGenerator(seed: 16)
        for _ in 0..<4 {
            var counts: [PracticeTopic: Int] = [:]
            for _ in 0..<9 {
                counts[try generator.next(progress: progress).topic, default: 0] += 1
            }
            XCTAssertEqual(counts[.drawPrice], 4)
            for topic in PracticeTopic.allCases where topic != .drawPrice { XCTAssertEqual(counts[topic], 1) }
        }
    }

    func testWeightedBonusesFavorHigherErrorRateAndMasteryStopsBonuses() throws {
        let progress = PracticeLearningProgress(stats: [
            .drawPrice: .init(attempts: 20, correct: 0),
            .valueBet: .init(attempts: 20, correct: 12),
            .checking: .init(attempts: 100, correct: 99)
        ])
        var generator = PracticeScenarioGenerator(seed: 41)
        var counts: [PracticeTopic: Int] = [:]
        for _ in 0..<(9 * 20) { counts[try generator.next(progress: progress).topic, default: 0] += 1 }
        XCTAssertGreaterThan(counts[.drawPrice, default: 0], counts[.valueBet, default: 0])
        XCTAssertEqual(counts[.checking], 20)
        XCTAssertEqual(counts.values.reduce(0, +), 180)

        let mastered = PracticeLearningProgress(stats: [.drawPrice: .init(attempts: 100, correct: 99)])
        let nextRound = try (0..<6).map { _ in try generator.next(progress: mastered).topic }
        XCTAssertEqual(Set(nextRound), Set(PracticeTopic.allCases))
    }

    func testBatchHasLegalDistinctFaceCardDealsAllActionsAndRealisticWagers() throws {
        var generator = PracticeScenarioGenerator(seed: 16)
        var choices: Set<PracticeChoice> = []
        var signatures: Set<[Card]> = []
        var textures: Set<BoardTexture> = []
        var sawNormalBet = false
        var sawOverbet = false
        var sawAllInCall = false
        var sawAllInRaise = false
        var sawCoveredRaise = false
        let allowedFractions = [0.25, 0.33, 0.5, 0.75, 1.0, 1.5]
        for _ in 0..<180 {
            let prepared = try generator.next()
            let scenario = prepared.scenario
            XCTAssertEqual(scenario.holeCards.count, 2)
            XCTAssertEqual(scenario.flop.count, 3)
            XCTAssertTrue(scenario.holeCards.allSatisfy { [.jack, .queen, .king].contains($0.rank) })
            XCTAssertEqual(try Deck.remaining(excluding: scenario.holeCards + scenario.flop).count, 47)
            XCTAssertNoThrow(try scenario.betting.validate())
            XCTAssertGreaterThan(scenario.betting.heroStack, 0)
            XCTAssertGreaterThan(scenario.betting.effectiveStack, 0)
            let analysis = try PostflopHeuristicEngine.analyze(holeCards: scenario.holeCards, board: scenario.flop, betting: scenario.betting, isPreflopAggressor: scenario.isPreflopAggressor)
            XCTAssertEqual(prepared.analysis, analysis)
            XCTAssertEqual(PreparedPracticeScenario.inferTopic(scenario: scenario, analysis: analysis), prepared.topic)
            XCTAssertTrue(prepared.availableChoices.contains(prepared.choice))
            if scenario.betting.amountToCall > 0 {
                let wager = scenario.betting.amountToCall
                let preBetPot = scenario.betting.pot - wager
                XCTAssertTrue([80.0, 100, 150, 200, 300, 400, 600].contains { abs($0 - preBetPot) < 1e-8 })
                let fraction = wager / preBetPot
                XCTAssertTrue(allowedFractions.contains { abs($0 - fraction) < 1e-8 })
                XCTAssertEqual(scenario.betting.minimumRaiseIncrement, max(10, wager), accuracy: 1e-8)
                XCTAssertGreaterThanOrEqual(scenario.betting.opponentStack, 0)
                XCTAssertFalse(prepared.availableChoices.contains(.bet))
                XCTAssertFalse(prepared.availableChoices.contains(.check))
                sawNormalBet = sawNormalBet || fraction <= 1
                sawOverbet = sawOverbet || fraction > 1
            } else {
                XCTAssertFalse(prepared.availableChoices.contains(.call))
                XCTAssertFalse(prepared.availableChoices.contains(.raise))
            }
            switch analysis.recommendation.action {
            case .allIn(let amount) where scenario.betting.amountToCall > 0:
                XCTAssertEqual(amount, scenario.betting.heroStack)
                if amount <= scenario.betting.callCost {
                    XCTAssertEqual(prepared.choice, .call)
                    sawAllInCall = true
                } else {
                    XCTAssertEqual(prepared.choice, .raise)
                    sawAllInRaise = true
                }
            case .raise(let amount):
                XCTAssertGreaterThanOrEqual(amount, scenario.betting.amountToCall + scenario.betting.minimumRaiseIncrement)
                XCTAssertLessThanOrEqual(amount, scenario.betting.effectiveStack)
                sawCoveredRaise = true
            default: break
            }
            choices.insert(prepared.choice)
            signatures.insert(scenario.holeCards.sorted() + scenario.flop.sorted())
            textures.insert(analysis.texture.texture)
        }
        XCTAssertEqual(choices, Set(PracticeChoice.allCases))
        XCTAssertGreaterThan(signatures.count, 160)
        XCTAssertEqual(textures, [.dryRainbow, .wetConnected, .monotone])
        XCTAssertTrue(sawNormalBet)
        XCTAssertTrue(sawOverbet)
        XCTAssertTrue(sawAllInCall)
        XCTAssertTrue(sawAllInRaise)
        XCTAssertTrue(sawCoveredRaise)
    }

    func testGeneratedModelReplaysWithTheSameAnswersAndProgress() async throws {
        try await MainActor.run {
            let first = PracticeViewModel(seed: 16)
            let second = PracticeViewModel(seed: 16)
            for number in 1...25 {
                XCTAssertEqual(first.scenarioNumber, number)
                XCTAssertNil(first.scenarioCount)
                XCTAssertEqual(first.currentScenario, second.currentScenario)
                let choice = try XCTUnwrap(first.availableChoices.first)
                first.submit(choice)
                second.submit(choice)
                XCTAssertEqual(first.feedback, second.feedback)
                XCTAssertEqual(first.learningProgress, second.learningProgress)
                XCTAssertEqual(first.attemptCount, number)
                first.nextScenario()
                second.nextScenario()
            }
            XCTAssertEqual(first.scenarioNumber, 26)
        }
    }

    func testConstructiveFallbackAlwaysConfirmsEachTopicWithFreshCards() throws {
        var signatures: Set<[Card]> = []
        for seed in 0..<12 {
            var generator = PracticeScenarioGenerator(seed: UInt64(seed))
            for topic in PracticeTopic.allCases {
                let prepared = try generator.constructiveFallback(for: topic, id: "fallback")
                XCTAssertEqual(prepared.topic, topic)
                XCTAssertEqual(PreparedPracticeScenario.inferTopic(scenario: prepared.scenario, analysis: prepared.analysis), topic)
                XCTAssertEqual(try Deck.remaining(excluding: prepared.scenario.holeCards + prepared.scenario.flop).count, 47)
                XCTAssertTrue(prepared.availableChoices.contains(prepared.choice))
                signatures.insert(prepared.scenario.holeCards.sorted() + prepared.scenario.flop.sorted())
            }
        }
        XCTAssertGreaterThan(signatures.count, 60)
    }

    func testWagerConstructionDeductsExactlyOnceAndCapsAnOpponentAllIn() throws {
        let ordinary = try PracticeScenarioGenerator.betting(
            preBetPot: 200, wagerFraction: 0.75, heroInitialStack: 1_000, opponentInitialStack: 800
        )
        XCTAssertEqual(ordinary.pot, 350)
        XCTAssertEqual(ordinary.amountToCall, 150)
        XCTAssertEqual(ordinary.heroStack, 1_000)
        XCTAssertEqual(ordinary.opponentStack, 650)
        XCTAssertEqual(ordinary.opponentStack + ordinary.amountToCall, 800)
        XCTAssertEqual(ordinary.minimumRaiseIncrement, 150)
        XCTAssertEqual(ordinary.effectiveStack, 800)

        let short = try PracticeScenarioGenerator.betting(
            preBetPot: 200, wagerFraction: 0.75, heroInitialStack: 500, opponentInitialStack: 70
        )
        XCTAssertEqual(short.pot, 270)
        XCTAssertEqual(short.amountToCall, 70)
        XCTAssertEqual(short.opponentStack, 0)
        XCTAssertEqual(short.minimumRaiseIncrement, 70)
        XCTAssertTrue(short.closesBettingByCalling)

        XCTAssertThrowsError(try PracticeScenarioGenerator.betting(
            preBetPot: 80, wagerFraction: 0.05, heroInitialStack: 500, opponentInitialStack: 500
        ))
        let tinyAllIn = try PracticeScenarioGenerator.betting(
            preBetPot: 80, wagerFraction: 0.5, heroInitialStack: 500, opponentInitialStack: 4
        )
        XCTAssertEqual(tinyAllIn.amountToCall, 4)
        XCTAssertEqual(tinyAllIn.opponentStack, 0)
    }

    func testInvalidWagerInputsAreRejectedAndCorruptProgressDoesNotAddReviews() throws {
        for invalid in [-1.0, Double.nan, .infinity] {
            XCTAssertThrowsError(try PracticeScenarioGenerator.betting(preBetPot: 200, wagerFraction: invalid, heroInitialStack: 500, opponentInitialStack: 500))
            XCTAssertThrowsError(try PracticeScenarioGenerator.betting(preBetPot: invalid, wagerFraction: 0.5, heroInitialStack: 500, opponentInitialStack: 500))
        }
        XCTAssertThrowsError(try PracticeScenarioGenerator.betting(preBetPot: .greatestFiniteMagnitude, wagerFraction: 2, heroInitialStack: 500, opponentInitialStack: 500))
        let corrupt = PracticeLearningProgress(stats: [.drawPrice: .init(attempts: -1, correct: 3)])
        var generator = PracticeScenarioGenerator(seed: 99)
        let topics = try (0..<6).map { _ in try generator.next(progress: corrupt).topic }
        XCTAssertEqual(Set(topics), Set(PracticeTopic.allCases))
    }
}
