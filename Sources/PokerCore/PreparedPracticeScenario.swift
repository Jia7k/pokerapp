struct PreparedPracticeScenario {
    let scenario: PracticeScenario
    let analysis: PostflopAnalysis
    let choice: PracticeChoice
    let availableChoices: [PracticeChoice]
    let topic: PracticeTopic

    init(_ scenario: PracticeScenario) throws {
        guard scenario.holeCards.count == 2, scenario.flop.count == 3 else {
            throw StrategyInputError.invalidBettingState(
                "A flop drill needs exactly two hole cards and three community cards."
            )
        }
        _ = try Deck.remaining(excluding: scenario.holeCards + scenario.flop)
        try scenario.betting.validate()
        guard scenario.betting.pot > 0,
              scenario.betting.heroStack > 0,
              scenario.betting.effectiveStack > 0 else {
            throw StrategyInputError.invalidBettingState(
                "A drill needs a positive pot and chips available in the effective stack."
            )
        }

        let analysis = try PostflopHeuristicEngine.analyze(
            holeCards: scenario.holeCards, board: scenario.flop,
            betting: scenario.betting,
            isPreflopAggressor: scenario.isPreflopAggressor
        )
        let choice: PracticeChoice
        switch (analysis.recommendation.action, scenario.betting.amountToCall == 0) {
        case (.bet, true), (.allIn, true):
            // An all-in is an opening Bet only when no wager is outstanding.
            choice = .bet
        case (.check, true):
            choice = .check
        case (.fold, false):
            choice = .fold
        case (.call, false):
            choice = .call
        case (.raise, false):
            choice = .raise
        case (.allIn(let amount), false):
            choice = amount <= scenario.betting.callCost ? .call : .raise
        default:
            throw PracticePreparationError.unsupportedChoice
        }
        let available = try Self.legalChoices(for: scenario.betting)
        guard available.contains(choice) else { throw PracticePreparationError.unsupportedChoice }
        self.scenario = scenario
        self.analysis = analysis
        self.choice = choice
        availableChoices = available
        topic = scenario.topic ?? Self.inferTopic(scenario: scenario, analysis: analysis)
    }

    static func inferTopic(scenario: PracticeScenario, analysis: PostflopAnalysis) -> PracticeTopic {
        switch analysis.recommendation.reason {
        case .dryBoardContinuationBet:
            .continuationBet
        case .shortStackValue:
            .shortStack
        case .drawPriceAcceptable:
            .drawPrice
        case .drawTooExpensive:
            analysis.outs.count > 0 && !analysis.madeHand.hasTopPairOrBetter ? .drawPrice : .facingBet
        case .madeHandValue:
            scenario.betting.amountToCall > 0 ? .facingBet : .valueBet
        default:
            scenario.betting.amountToCall > 0 ? .facingBet : .checking
        }
    }

    private static func legalChoices(for betting: BettingState) throws -> [PracticeChoice] {
        if betting.amountToCall == 0 {
            switch try betting.sizedBet(potFraction: 1) {
            case .bet, .allIn: return [.check, .bet]
            default: return [.check]
            }
        }

        // A maximum effective commitment is a raise only if the existing sizing
        // rules permit a full raise or an actual short hero all-in above the call.
        switch try betting.commitEffectiveStack() {
        case .raise:
            return [.fold, .call, .raise]
        case .allIn(let amount) where amount > betting.callCost:
            return [.fold, .call, .raise]
        default:
            return [.fold, .call]
        }
    }
}

enum PracticePreparationError: Error, CustomStringConvertible {
    case unsupportedChoice

    var description: String {
        "The engine did not return a legal action for this practice scenario."
    }
}
