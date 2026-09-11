import Observation
import XCTest
import PokerCore

@MainActor private func fill(_ model: PokerViewModel, hole: String, board: String = "") throws {
    for (index, card) in cards(hole).enumerated() { try model.setCard(card, at: .hole(index)) }
    for (index, card) in cards(board).enumerated() {
        let slot: CardSlot = index < 3 ? .flop(index) : index == 3 ? .turn : .river
        try model.setCard(card, at: slot)
    }
}

private final class ObservationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = false
    func mark() { lock.lock(); defer { lock.unlock() }; storage = true }
    var value: Bool { lock.lock(); defer { lock.unlock() }; return storage }
}

final class PokerViewModelTests: XCTestCase {
    func testUnrepresentableCoveredRaiseFallsBackToFiniteCall() async throws {
        try await MainActor.run {
            let model = PokerViewModel(
                betting: BettingState(
                    pot: 1.1e308, amountToCall: 1e307, heroStack: 1.7e308,
                    opponentStack: 1e308, heroStreetContribution: 1e308
                ), preflopSituation: .facingOpenRaise
            )
            try fill(model, hole: "As Ah")
            XCTAssertEqual(model.analysis.status, .ready)
            XCTAssertEqual(model.analysis.recommendation?.action, .call(amount: 1e307))
        }
    }

    func testUncallablyLargeOpenMapsPremiumHandToFiniteAllIn() async throws {
        try await MainActor.run {
            let model = PokerViewModel(
                betting: BettingState(pot: 1e308, amountToCall: 1e308),
                preflopSituation: .facingOpenRaise
            )
            try fill(model, hole: "As Ah")
            XCTAssertEqual(model.analysis.status, .ready)
            XCTAssertEqual(model.analysis.recommendation?.action, .allIn(amount: 1_000))
            XCTAssertEqual(model.analysis.requiredEquity, 0.5)
        }
    }

    func testVerySmallBlindUsesDeepChartWithoutInfiniteDepthError() async throws {
        try await MainActor.run {
            let model = PokerViewModel(betting: BettingState(bigBlind: 1e-308))
            try fill(model, hole: "As Ah")
            XCTAssertEqual(model.analysis.status, .ready)
            XCTAssertEqual(model.analysis.chartDepth, .bb100)
            XCTAssertNotNil(model.analysis.recommendation)
        }
    }

    func testDepthDividesBeforeAddingPotentiallyOverflowingChipTotals() async throws {
        try await MainActor.run {
            let model = PokerViewModel(betting: BettingState(
                pot: 1e308, heroStack: 1e308, opponentStack: 1e308,
                bigBlind: 1e308, heroStreetContribution: 1e308
            ))
            try fill(model, hole: "As Ah")
            XCTAssertEqual(model.analysis.status, .ready)
            XCTAssertEqual(model.analysis.chartDepth, .bb20)
            XCTAssertEqual(model.analysis.recommendation?.action, .allIn(amount: 1e308))
        }
    }

    func testButtonExampleConnectsChartToChipSizing() async throws {
        try await MainActor.run {
            let model = PokerViewModel(betting: BettingState(pot: 15, amountToCall: 10, heroStack: 400, opponentStack: 390))
            XCTAssertEqual(model.analysis.status, .awaitingHoleCards)
            try fill(model, hole: "Ah 5h")
            XCTAssertEqual(model.analysis.status, .ready)
            XCTAssertEqual(model.analysis.street, .preflop)
            XCTAssertEqual(model.analysis.chartDepth, .bb40)
            XCTAssertEqual(model.analysis.recommendation?.action, .raise(to: 25))
            XCTAssertNil(model.analysis.approximateDrawProbability)
        }
    }

    func testPartialFlopClearsOldPreflopRecommendation() async throws {
        try await MainActor.run {
            let model = PokerViewModel()
            try fill(model, hole: "Ah Kh")
            XCTAssertNotNil(model.analysis.recommendation)
            try model.setCard(cards("Qs")[0], at: .flop(0))
            XCTAssertEqual(model.analysis.status, .awaitingFlop)
            XCTAssertNil(model.analysis.recommendation)
            XCTAssertNil(model.analysis.outs)
        }
    }

    func testCompleteFlopConnectsOwnedTopPairAndShortStackHeuristic() async throws {
        try await MainActor.run {
            let model = PokerViewModel(betting: BettingState(pot: 100, heroStack: 80, opponentStack: 500))
            try fill(model, hole: "Kh Qc", board: "Ks 8d 2c")
            XCTAssertEqual(model.analysis.recommendation?.action, .allIn(amount: 80))
            XCTAssertEqual(model.analysis.texture?.texture, .dryRainbow)
            XCTAssertEqual(model.analysis.hand?.category, .onePair)
            XCTAssertEqual(model.analysis.effectiveStack, 80)
            XCTAssertEqual(model.analysis.stackToPotRatio, 0.8)
        }
    }

    func testNestedBettingEditRecomputesOddsAndDecisionWithoutChangingBankroll() async throws {
        try await MainActor.run {
            let model = PokerViewModel(bankroll: 5_000, betting: BettingState(pot: 150, amountToCall: 50))
            try fill(model, hole: "Ah 7h", board: "Kh 2h 9c")
            XCTAssertEqual(model.analysis.recommendation?.action, .fold)
            XCTAssertEqual(model.analysis.approximateDrawProbability, 0.36)
            XCTAssertEqual(model.analysis.requiredEquity, 0.25)
            model.betting.pot = 500
            XCTAssertEqual(model.analysis.recommendation?.action, .call(amount: 50))
            XCTAssertEqual(try XCTUnwrap(model.analysis.requiredEquity), 50.0 / 550, accuracy: 1e-12)
            XCTAssertEqual(model.bankroll, 5_000)
            XCTAssertEqual(model.betting.heroStack, 1_000)
        }
    }

    func testObservationNotifiesWhenDerivedAnalysisChanges() async throws {
        try await MainActor.run {
            let model = PokerViewModel()
            let flag = ObservationFlag()
            withObservationTracking { _ = model.analysis } onChange: { flag.mark() }
            try model.setCard(cards("As")[0], at: .hole(0))
            XCTAssertTrue(flag.value)
        }
    }

    func testDuplicateAndInvalidSlotRejectionsAreAtomic() async throws {
        try await MainActor.run {
            let model = PokerViewModel()
            try fill(model, hole: "As Kh")
            let before = model.analysis
            XCTAssertThrowsError(try model.setCard(cards("As")[0], at: .hole(1)))
            XCTAssertThrowsError(try model.setCard(cards("Qd")[0], at: .hole(2)))
            XCTAssertThrowsError(try model.setCard(cards("Qd")[0], at: .flop(3)))
            XCTAssertEqual(try model.card(at: .hole(1)), cards("Kh")[0])
            XCTAssertEqual(model.analysis, before)
            try model.setCard(cards("As")[0], at: .hole(0))
            XCTAssertEqual(model.selectedCards.count, 2)
        }
    }

    func testAvailableCardsAllowCurrentSelectionButExcludeOtherSlots() async throws {
        try await MainActor.run {
            let model = PokerViewModel()
            try fill(model, hole: "As Kh")
            let available = try model.availableCards(for: .hole(0))
            XCTAssertEqual(available.count, 51)
            XCTAssertTrue(available.contains(cards("As")[0]))
            XCTAssertFalse(available.contains(cards("Kh")[0]))
            XCTAssertThrowsError(try model.availableCards(for: .flop(-1)))
        }
    }

    func testLaterStreetsRequireEarlierBoardAndClearingRemovesDownstreamCards() async throws {
        try await MainActor.run {
            let model = PokerViewModel()
            try fill(model, hole: "As Kh")
            XCTAssertThrowsError(try model.setCard(cards("Ts")[0], at: .turn))
            XCTAssertThrowsError(try model.setCard(cards("9d")[0], at: .river))
            try fill(model, hole: "As Kh", board: "Qd Jc 2s Ts 9d")
            try model.setCard(nil, at: .turn)
            XCTAssertNil(try model.card(at: .river))
            XCTAssertEqual(model.analysis.street, .flop)
            try model.setCard(cards("Ts")[0], at: .turn)
            try model.setCard(cards("9d")[0], at: .river)
            try model.setCard(nil, at: .flop(1))
            XCTAssertNil(try model.card(at: .turn))
            XCTAssertNil(try model.card(at: .river))
            XCTAssertEqual(model.analysis.status, .awaitingFlop)
        }
    }

    func testInvalidNumbersClearAdviceAndValidEditRecovers() async throws {
        try await MainActor.run {
            let model = PokerViewModel()
            try fill(model, hole: "As Kh", board: "Qd Jc 2s")
            model.betting.pot = .nan
            XCTAssertEqual(model.analysis.status, .invalidInput)
            XCTAssertNil(model.analysis.recommendation)
            XCTAssertNil(model.analysis.outs)
            XCTAssertNotNil(model.analysis.message)
            model.betting.pot = 100
            XCTAssertEqual(model.analysis.status, .ready)
            model.bankroll = -1
            XCTAssertEqual(model.analysis.status, .invalidInput)
            model.bankroll = 5_000
            XCTAssertEqual(model.analysis.status, .ready)
        }
    }

    func testFacingRaiseMapsThreeBetAndRejectsInconsistentSituation() async throws {
        try await MainActor.run {
            let model = PokerViewModel(preflopSituation: .facingOpenRaise)
            try fill(model, hole: "As Ah")
            XCTAssertEqual(model.analysis.status, .invalidInput)
            model.betting = BettingState(pot: 75, amountToCall: 30, minimumRaiseIncrement: 20)
            XCTAssertEqual(model.analysis.recommendation?.action, .raise(to: 90))
            model.betting.opponentStack = 0
            XCTAssertEqual(model.analysis.recommendation?.action, .call(amount: 30))
        }
    }

    func testFreeBigBlindAndAlreadyAllInHaveNoFoldOrZeroBet() async throws {
        try await MainActor.run {
            let model = PokerViewModel(betting: BettingState(pot: 15, heroStack: 990, heroStreetContribution: 10), position: .bigBlind)
            try fill(model, hole: "7s 2d")
            XCTAssertEqual(model.analysis.recommendation?.action, .check)
            model.betting.heroStack = 0
            XCTAssertEqual(model.analysis.recommendation?.action, .noAction)
        }
    }

    func testRiverMadeHandKeepsValueRecommendationWithNoDrawEstimate() async throws {
        try await MainActor.run {
            let model = PokerViewModel(betting: BettingState(pot: 300, amountToCall: 50))
            try fill(model, hole: "Ah Ad", board: "Ac Kc 2d 9s 3h")
            XCTAssertEqual(model.analysis.street, .river)
            XCTAssertEqual(model.analysis.outs?.count, 0)
            XCTAssertNil(model.analysis.approximateDrawProbability)
            XCTAssertNil(model.analysis.decisionDrawProbability)
            XCTAssertEqual(model.analysis.recommendation?.action, .call(amount: 50))
        }
    }

    func testResetHandPreservesBalancesAndClearsBettingHistory() async throws {
        try await MainActor.run {
            let model = PokerViewModel(bankroll: 5_000, betting: BettingState(pot: 300, amountToCall: 50, heroStack: 900, opponentStack: 700), position: .cutoff, isPreflopAggressor: true)
            try fill(model, hole: "Ah Ad", board: "Ac Kc 2d")
            model.resetHand()
            XCTAssertEqual(model.analysis.status, .awaitingHoleCards)
            XCTAssertTrue(model.selectedCards.isEmpty)
            XCTAssertEqual(model.bankroll, 5_000)
            XCTAssertEqual(model.betting.heroStack, 900)
            XCTAssertEqual(model.betting.opponentStack, 700)
            XCTAssertEqual(model.betting.pot, 0)
            XCTAssertEqual(model.betting.amountToCall, 0)
            XCTAssertEqual(model.position, .cutoff)
            XCTAssertFalse(model.isPreflopAggressor)
            XCTAssertEqual(model.preflopSituation, .unopened)
        }
    }
}
