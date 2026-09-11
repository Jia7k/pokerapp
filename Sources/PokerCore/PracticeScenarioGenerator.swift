struct PreparedPracticeScenario {
    let scenario: PracticeScenario
    let analysis: PostflopAnalysis
    let choice: PracticeChoice

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
        default:
            throw PracticePreparationError.unsupportedChoice
        }
        self.scenario = scenario
        self.analysis = analysis
        self.choice = choice
    }
}

private enum PracticePreparationError: Error, CustomStringConvertible {
    case unsupportedChoice

    var description: String {
        "This drill needs an action outside the Bet, Check and Fold choices."
    }
}

/// Generates a single fresh drill on demand without retaining a scenario history.
struct PracticeScenarioGenerator {
    private static let faceCards = Deck.allCards.filter { [.jack, .queen, .king].contains($0.rank) }
    private var random: SplitMix64
    private var nextOrdinal: UInt64 = 1

    init(seed: UInt64) {
        random = SplitMix64(state: seed)
    }

    mutating func next() throws -> PreparedPracticeScenario {
        let id = "generated-\(nextOrdinal)"
        nextOrdinal &+= 1
        var candidate = try randomScenario(id: id)

        // At most four independent candidates and one checked-to fallback:
        // a string of unrepresentable Call/Raise answers cannot stall practice.
        for attempt in 0..<4 {
            if attempt > 0 { candidate = try randomScenario(id: id) }
            do {
                return try PreparedPracticeScenario(candidate)
            } catch PracticePreparationError.unsupportedChoice {
                continue
            }
        }
        return try Self.checkedToFallback(from: candidate)
    }

    static func checkedToFallback(from scenario: PracticeScenario) throws -> PreparedPracticeScenario {
        // Keep the fresh deal, then reanalyze a live checked-to decision. Under
        // the existing engine this always has an opening Bet or Check answer.
        var betting = scenario.betting
        betting.amountToCall = 0
        return try PreparedPracticeScenario(PracticeScenario(
            id: scenario.id, holeCards: scenario.holeCards, flop: scenario.flop,
            betting: betting, isPreflopAggressor: scenario.isPreflopAggressor
        ))
    }

    private mutating func randomScenario(id: String) throws -> PracticeScenario {
        var faceCards = Self.faceCards
        faceCards.shuffle(using: &random)
        let holeCards = Array(faceCards.prefix(2))
        var deck = try Deck(excluding: holeCards)
        deck.shuffle(using: &random)
        var flop: [Card] = []
        for _ in 0..<3 {
            guard let card = deck.draw() else {
                throw StrategyInputError.invalidBettingState("The practice deck could not deal a complete flop.")
            }
            flop.append(card)
        }

        let bigBlind = 10.0
        let potUnits = [8, 10, 15, 20, 30, 40, 60]
        let pot = Double(potUnits[Int.random(in: potUnits.indices, using: &random)]) * bigBlind
        let stackRatios = [0.5, 0.75, 1.0, 2.0, 4.0, 6.0]
        let coveredStack = pot * stackRatios[Int.random(in: stackRatios.indices, using: &random)]
        let extraStack = Double(Int.random(in: 0...10, using: &random)) * bigBlind
        let heroIsCovered = Bool.random(using: &random)
        let heroStack = coveredStack + (heroIsCovered ? 0 : extraStack)
        let opponentStack = coveredStack + (heroIsCovered ? extraStack : 0)
        let callFractions = [0.25, 0.5, 0.75]
        let facesBet = Int.random(in: 0..<3, using: &random) == 0
        // The displayed pot already includes this outstanding wager.
        let amountToCall = facesBet
            ? pot * callFractions[Int.random(in: callFractions.indices, using: &random)]
            : 0
        return PracticeScenario(
            id: id, holeCards: holeCards, flop: flop,
            betting: BettingState(
                pot: pot, amountToCall: amountToCall, heroStack: heroStack,
                opponentStack: opponentStack, bigBlind: bigBlind
            ),
            isPreflopAggressor: Bool.random(using: &random)
        )
    }
}

/// Small deterministic RNG; system entropy supplies the default session seed.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
