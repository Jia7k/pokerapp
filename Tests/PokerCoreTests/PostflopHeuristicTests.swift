import XCTest
import PokerCore

final class PostflopHeuristicTests: XCTestCase {
    func testTextureClassifiesDryWetAndMonotoneFlops() throws {
        let dry = try BoardTextureAnalyzer.analyze(cards("Ks 8d 2c"))
        XCTAssertEqual(dry.texture, .dryRainbow)
        XCTAssertEqual(dry.maximumSuitCount, 1)
        XCTAssertFalse(dry.isConnected)

        let wet = try BoardTextureAnalyzer.analyze(cards("Jh Th 9s"))
        XCTAssertEqual(wet.texture, .wetConnected)
        XCTAssertEqual(wet.maximumSuitCount, 2)
        XCTAssertTrue(wet.isConnected)

        let monotone = try BoardTextureAnalyzer.analyze(cards("As 8s 2s"))
        XCTAssertEqual(monotone.texture, .monotone)
        XCTAssertEqual(monotone.maximumSuitCount, 3)
    }

    func testTextureReportsPairingAndAceLowWindowsWithoutRankWraparound() throws {
        let paired = try BoardTextureAnalyzer.analyze(cards("Ks Kd 2c"))
        XCTAssertTrue(paired.isPaired)

        let wheelWindow = try BoardTextureAnalyzer.analyze(cards("As 2d 3c"))
        XCTAssertTrue(wheelWindow.isConnected)
        XCTAssertEqual(wheelWindow.texture, .wetConnected)

        let noWraparound = try BoardTextureAnalyzer.analyze(cards("As Kd 2c"))
        XCTAssertFalse(noWraparound.isConnected)
        XCTAssertEqual(noWraparound.texture, .dryRainbow)
    }

    func testTextureUsesWholeTurnAndRiverBoard() throws {
        let turn = try BoardTextureAnalyzer.analyze(cards("Ks 4d 2c 3h"))
        XCTAssertEqual(turn.texture, .wetConnected)
        XCTAssertTrue(turn.isConnected)

        let river = try BoardTextureAnalyzer.analyze(cards("Ks 8d 2c 4h 5s"))
        XCTAssertEqual(river.texture, .wetConnected)
        XCTAssertTrue(river.isConnected)
    }

    func testTextureRejectsWrongCountsAndDuplicateCards() {
        XCTAssertThrowsError(try BoardTextureAnalyzer.analyze(cards("Ks 8d")))
        XCTAssertThrowsError(try BoardTextureAnalyzer.analyze(cards("Ks 8d 2c 3h 4s 5d")))
        XCTAssertThrowsError(try BoardTextureAnalyzer.analyze(cards("Ks Ks 2c")))
    }

    func testTopPairAndLowSPRCommitsHeroStack() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Kh Qd"), board: cards("Ks 8d 2c"),
            betting: BettingState(pot: 100, heroStack: 80, opponentStack: 500),
            isPreflopAggressor: false
        )
        XCTAssertEqual(result.madeHand.value.category, .onePair)
        XCTAssertTrue(result.madeHand.hasTopPairOrBetter)
        XCTAssertFalse(result.madeHand.isStrongMadeHand)
        XCTAssertEqual(result.recommendation.action, .allIn(amount: 80))
        XCTAssertEqual(result.recommendation.reason, .shortStackValue)
    }

    func testLowSPRCommitmentUsesMatchedCallAgainstAllInOpponent() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Kh Qd"), board: cards("Ks 8d 2c"),
            betting: BettingState(pot: 100, amountToCall: 30, heroStack: 80, opponentStack: 0),
            isPreflopAggressor: true
        )
        XCTAssertEqual(result.recommendation.action, .call(amount: 30))
        XCTAssertEqual(result.recommendation.reason, .shortStackValue)
        XCTAssertFalse(result.recommendation.explanation.localizedCaseInsensitiveContains("hero all-in"))
    }

    func testBoardPairTripsAndQuadsDoNotBecomeHeroMadeHandStrength() throws {
        let pair = try analyzeChecked(hole: "As Qd", board: "Ks Kd 2c")
        XCTAssertEqual(pair.madeHand.value.category, .onePair)
        XCTAssertFalse(pair.madeHand.hasTopPairOrBetter)
        XCTAssertFalse(pair.madeHand.isStrongMadeHand)

        let trips = try analyzeChecked(hole: "As Qd", board: "Ks Kd Kh")
        XCTAssertEqual(trips.madeHand.value.category, .threeOfAKind)
        XCTAssertFalse(trips.madeHand.hasTopPairOrBetter)
        XCTAssertFalse(trips.madeHand.isStrongMadeHand)

        let quads = try analyzeChecked(hole: "As Qd", board: "Ks Kd Kh Kc 2s")
        XCTAssertEqual(quads.madeHand.value.category, .fourOfAKind)
        XCTAssertFalse(quads.madeHand.hasTopPairOrBetter)
        XCTAssertFalse(quads.madeHand.isStrongMadeHand)
        XCTAssertFalse(quads.madeHand.playsBoard)
        XCTAssertEqual(quads.recommendation.reason, .boardOnlyHand)
    }

    func testHolePairImprovesBoardFullHouseAndCountsAsHeroStrength() throws {
        let result = try analyzeChecked(hole: "As Ad", board: "Ks Kd Kh 2c 2d")
        XCTAssertEqual(result.madeHand.value.category, .fullHouse)
        XCTAssertEqual(result.madeHand.value.tiebreakers, [.king, .ace])
        XCTAssertTrue(result.madeHand.hasTopPairOrBetter)
        XCTAssertTrue(result.madeHand.isStrongMadeHand)
        XCTAssertFalse(result.madeHand.playsBoard)
    }

    func testBoardStraightIsMarkedAsPlayingBoard() throws {
        let result = try analyzeChecked(hole: "2c 3d", board: "9h Ts Jc Qd Kh")
        XCTAssertEqual(result.madeHand.value.category, .straight)
        XCTAssertTrue(result.madeHand.playsBoard)
        XCTAssertFalse(result.madeHand.hasTopPairOrBetter)
        XCTAssertFalse(result.madeHand.isStrongMadeHand)
        XCTAssertEqual(result.recommendation.reason, .boardOnlyHand)
    }

    func testFourOutsAtSixteenPercentFoldAgainstTwentyFivePercentAllInPrice() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Ac Kd"), board: cards("Qh Js 2c"),
            betting: BettingState(pot: 150, amountToCall: 50, opponentStack: 0),
            isPreflopAggressor: false
        )
        XCTAssertEqual(result.outs.count, 4)
        XCTAssertEqual(try XCTUnwrap(result.approximateDrawProbability), 0.16, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(result.decisionDrawProbability), 0.16, accuracy: 1e-12)
        XCTAssertEqual(result.recommendation.action, .fold)
        XCTAssertEqual(result.recommendation.reason, .drawTooExpensive)
    }

    func testOrdinaryFlopCallUsesExactNextCardProbabilityInsteadOfRuleOfFour() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Ah 7h"), board: cards("Kh 2h 9c"),
            betting: BettingState(pot: 150, amountToCall: 50),
            isPreflopAggressor: true
        )
        XCTAssertEqual(result.outs.count, 9)
        XCTAssertEqual(try XCTUnwrap(result.approximateDrawProbability), 0.36, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(result.decisionDrawProbability), 9.0 / 47.0, accuracy: 1e-12)
        XCTAssertEqual(result.recommendation.action, .fold)
        XCTAssertEqual(result.recommendation.reason, .drawTooExpensive)
    }

    func testAllInOpponentLetsFlopCallUseRuleOfFourHorizon() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Ah 7h"), board: cards("Kh 2h 9c"),
            betting: BettingState(pot: 150, amountToCall: 50, opponentStack: 0),
            isPreflopAggressor: false
        )
        XCTAssertEqual(try XCTUnwrap(result.decisionDrawProbability), 0.36, accuracy: 1e-12)
        XCTAssertEqual(result.recommendation.action, .call(amount: 50))
        XCTAssertEqual(result.recommendation.reason, .drawPriceAcceptable)
    }

    func testTurnDisplaysRuleOfTwoButPricesCallWithExactNextCardProbability() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Ah 7h"), board: cards("Kh 2h 9c 3d"),
            betting: BettingState(pot: 900, amountToCall: 100),
            isPreflopAggressor: false
        )
        XCTAssertEqual(result.outs.count, 9)
        XCTAssertEqual(try XCTUnwrap(result.approximateDrawProbability), 0.18, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(result.decisionDrawProbability), 9.0 / 46.0, accuracy: 1e-12)
        XCTAssertEqual(result.recommendation.action, .call(amount: 100))
    }

    func testExactTurnProbabilityCallsAtNineteenPercentPrice() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Ah 7h"), board: cards("Kh 2h 9c 3d"),
            betting: BettingState(
                pot: 810, amountToCall: 190,
                heroStack: 1_000, opponentStack: 1_000
            ),
            isPreflopAggressor: false
        )
        XCTAssertEqual(result.outs.count, 9)
        XCTAssertEqual(try XCTUnwrap(result.approximateDrawProbability), 0.18, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(result.decisionDrawProbability), 9.0 / 46.0, accuracy: 1e-12)
        XCTAssertEqual(result.recommendation.action, .call(amount: 190))
        XCTAssertEqual(result.recommendation.reason, .drawPriceAcceptable)
    }

    func testFacingBetNeverTakesDryBoardContinuationBetBranch() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Ah Qd"), board: cards("Ks 8d 2c"),
            betting: BettingState(pot: 150, amountToCall: 50),
            isPreflopAggressor: true
        )
        XCTAssertEqual(result.recommendation.action, .fold)
        XCTAssertEqual(result.recommendation.reason, .drawTooExpensive)
    }

    func testRiverStrongMadeHandCallsDespiteHavingNoOuts() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Ac Kd"), board: cards("Ah Ks 2d 7c 9h"),
            betting: BettingState(pot: 200, amountToCall: 50),
            isPreflopAggressor: false
        )
        XCTAssertEqual(result.madeHand.value.category, .twoPair)
        XCTAssertTrue(result.madeHand.isStrongMadeHand)
        XCTAssertEqual(result.outs.count, 0)
        XCTAssertNil(result.approximateDrawProbability)
        XCTAssertNil(result.decisionDrawProbability)
        XCTAssertEqual(result.recommendation.action, .call(amount: 50))
        XCTAssertEqual(result.recommendation.reason, .madeHandValue)
    }

    func testTopPairCallsAtOneThirdPriceAndFoldsAboveIt() throws {
        let call = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Kh Qd"), board: cards("Ks 8d 2c"),
            betting: BettingState(pot: 100, amountToCall: 50, heroStack: 500, opponentStack: 500),
            isPreflopAggressor: false
        )
        XCTAssertEqual(call.recommendation.action, .call(amount: 50))
        XCTAssertEqual(call.recommendation.reason, .madeHandValue)

        let fold = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Kh Qd"), board: cards("Ks 8d 2c"),
            betting: BettingState(pot: 90, amountToCall: 50, heroStack: 500, opponentStack: 500),
            isPreflopAggressor: false
        )
        XCTAssertEqual(fold.recommendation.action, .fold)
        XCTAssertEqual(fold.recommendation.reason, .drawTooExpensive)
    }

    func testCheckedToDryFlopAggressorBetsOneThirdPot() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Ah Qd"), board: cards("Ks 8d 2c"),
            betting: BettingState(pot: 300), isPreflopAggressor: true
        )
        XCTAssertEqual(result.recommendation.action, .bet(amount: 99))
        XCTAssertEqual(result.recommendation.reason, .dryBoardContinuationBet)
    }

    func testContinuationBetDelegatesMinimumAndStackCapsToBettingHelpers() throws {
        let minimum = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Ah Qd"), board: cards("Ks 8d 2c"),
            betting: BettingState(pot: 10), isPreflopAggressor: true
        )
        XCTAssertEqual(minimum.recommendation.action, .bet(amount: 10))

        let heroCap = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Ah Qd"), board: cards("Ks 8d 2c"),
            betting: BettingState(pot: 300, heroStack: 50), isPreflopAggressor: true
        )
        XCTAssertEqual(heroCap.recommendation.action, .allIn(amount: 50))

        let opponentCap = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Ah Qd"), board: cards("Ks 8d 2c"),
            betting: BettingState(pot: 300, opponentStack: 50), isPreflopAggressor: true
        )
        XCTAssertEqual(opponentCap.recommendation.action, .bet(amount: 50))
    }

    func testWetWeakHandChecksWhenActionIsFree() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("As 4d"), board: cards("Jh Th 9s"),
            betting: BettingState(pot: 300), isPreflopAggressor: true
        )
        XCTAssertEqual(result.recommendation.action, .check)
        XCTAssertEqual(result.recommendation.reason, .checkWithoutValue)
    }

    func testBoardOnlyHandChecksRatherThanShowingFoldWhenActionIsFree() throws {
        let result = try analyzeChecked(hole: "As Qd", board: "Ks Kd Kh")
        XCTAssertEqual(result.recommendation.action, .check)
        XCTAssertEqual(result.recommendation.reason, .boardOnlyHand)
    }

    func testHeroContributedMiddlePairIsNotLabeledBoardOnly() throws {
        let result = try analyzeChecked(hole: "9h 8c", board: "Kd 9c 2s")
        XCTAssertEqual(result.madeHand.value.category, .onePair)
        XCTAssertFalse(result.madeHand.hasTopPairOrBetter)
        XCTAssertEqual(result.recommendation.action, .check)
        XCTAssertEqual(result.recommendation.reason, .checkWithoutValue)
    }

    func testRoyalFlushOnBoardIsAGuaranteedSplitWhenFacingBet() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("2c 3d"), board: cards("As Ks Qs Js Ts"),
            betting: BettingState(pot: 150, amountToCall: 50),
            isPreflopAggressor: false
        )
        XCTAssertTrue(result.madeHand.playsBoard)
        XCTAssertEqual(result.recommendation.action, .call(amount: 50))
        XCTAssertEqual(result.recommendation.reason, .guaranteedSplit)
    }

    func testAceKickerBoardQuadsIsAGuaranteedSplit() throws {
        let facingBet = try PostflopHeuristicEngine.analyze(
            holeCards: cards("2c 3d"), board: cards("Kh Kd Ks Kc Ah"),
            betting: BettingState(pot: 150, amountToCall: 50),
            isPreflopAggressor: false
        )
        XCTAssertTrue(facingBet.madeHand.playsBoard)
        XCTAssertEqual(facingBet.recommendation.action, .call(amount: 50))
        XCTAssertEqual(facingBet.recommendation.reason, .guaranteedSplit)

        let checked = try analyzeChecked(hole: "2c 3d", board: "Kh Kd Ks Kc Ah")
        XCTAssertEqual(checked.recommendation.action, .check)
        XCTAssertEqual(checked.recommendation.reason, .guaranteedSplit)
    }

    func testOrdinaryBoardStraightAndFlushAreNotCalledGuaranteedSplits() throws {
        let straight = try PostflopHeuristicEngine.analyze(
            holeCards: cards("2c 3d"), board: cards("9h Ts Jc Qd Kh"),
            betting: BettingState(pot: 150, amountToCall: 50),
            isPreflopAggressor: false
        )
        XCTAssertEqual(straight.recommendation.action, .fold)
        XCTAssertEqual(straight.recommendation.reason, .drawTooExpensive)

        let flush = try PostflopHeuristicEngine.analyze(
            holeCards: cards("3c 4d"), board: cards("Ah Kh 8h 5h 2h"),
            betting: BettingState(pot: 150, amountToCall: 50),
            isPreflopAggressor: false
        )
        XCTAssertEqual(flush.recommendation.action, .fold)
        XCTAssertEqual(flush.recommendation.reason, .drawTooExpensive)
    }

    func testCoverageBelowMinimumTurnsContinuationBetIntoExplainedCheck() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Ah Qd"), board: cards("Ks 8d 2c"),
            betting: BettingState(pot: 5, opponentStack: 5),
            isPreflopAggressor: true
        )
        XCTAssertEqual(result.recommendation.action, .check)
        XCTAssertEqual(result.recommendation.reason, .insufficientCoverage)
        XCTAssertTrue(result.recommendation.explanation.localizedCaseInsensitiveContains("check"))
    }

    func testCoverageBelowMinimumTurnsValueBetIntoExplainedCheck() throws {
        let result = try PostflopHeuristicEngine.analyze(
            holeCards: cards("Kh 9d"), board: cards("Ks 9c 2s"),
            betting: BettingState(pot: 5, opponentStack: 5),
            isPreflopAggressor: false
        )
        XCTAssertTrue(result.madeHand.isStrongMadeHand)
        XCTAssertEqual(result.recommendation.action, .check)
        XCTAssertEqual(result.recommendation.reason, .insufficientCoverage)
        XCTAssertTrue(result.recommendation.explanation.localizedCaseInsensitiveContains("check"))
    }

    func testTerminalStackStatesReturnNoActionOrCheck() throws {
        let heroAllIn = try PostflopHeuristicEngine.analyze(
            holeCards: cards("As Qd"), board: cards("Ks 8d 2c"),
            betting: BettingState(pot: 100, heroStack: 0), isPreflopAggressor: true
        )
        XCTAssertEqual(heroAllIn.recommendation.action, .noAction)
        XCTAssertEqual(heroAllIn.recommendation.reason, .alreadyAllIn)

        let opponentAllIn = try PostflopHeuristicEngine.analyze(
            holeCards: cards("As Qd"), board: cards("Ks 8d 2c"),
            betting: BettingState(pot: 100, opponentStack: 0), isPreflopAggressor: true
        )
        XCTAssertEqual(opponentAllIn.recommendation.action, .check)
        XCTAssertEqual(opponentAllIn.recommendation.reason, .opponentAllIn)
    }

    func testEngineRejectsCardAndBettingInputErrors() {
        XCTAssertThrowsError(try PostflopHeuristicEngine.analyze(
            holeCards: cards("As"), board: cards("Ks 8d 2c"),
            betting: BettingState(), isPreflopAggressor: false
        ))
        XCTAssertThrowsError(try PostflopHeuristicEngine.analyze(
            holeCards: cards("As Qd"), board: cards("Ks 8d"),
            betting: BettingState(), isPreflopAggressor: false
        ))
        XCTAssertThrowsError(try PostflopHeuristicEngine.analyze(
            holeCards: cards("As Qd"), board: cards("As 8d 2c"),
            betting: BettingState(), isPreflopAggressor: false
        ))
        XCTAssertThrowsError(try PostflopHeuristicEngine.analyze(
            holeCards: cards("As Qd"), board: cards("Ks 8d 2c"),
            betting: BettingState(pot: -1), isPreflopAggressor: false
        ))
    }

    private func analyzeChecked(hole: String, board: String) throws -> PostflopAnalysis {
        try PostflopHeuristicEngine.analyze(
            holeCards: cards(hole), board: cards(board),
            betting: BettingState(pot: 300), isPreflopAggressor: false
        )
    }
}
