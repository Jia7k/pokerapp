public enum PracticeChoice: String, CaseIterable, Identifiable, Sendable {
    case bet, check, fold
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .bet: "Bet"
        case .check: "Check"
        case .fold: "Fold"
        }
    }
}

public struct PracticeScenario: Identifiable, Equatable, Sendable {
    public let id: String
    public let holeCards: [Card]
    public let flop: [Card]
    public let betting: BettingState
    public let isPreflopAggressor: Bool

    public init(id: String, holeCards: [Card], flop: [Card], betting: BettingState, isPreflopAggressor: Bool) {
        self.id = id
        self.holeCards = holeCards
        self.flop = flop
        self.betting = betting
        self.isPreflopAggressor = isPreflopAggressor
    }
}

public enum PracticeScenarioCatalog {
    /// Inputs only: the shared postflop engine computes every answer when loaded.
    public static let faceCardDrills: [PracticeScenario] = [
        make(
            "dry-continuation-bet",
            hole: [card(.king, .spades), card(.queen, .spades)],
            flop: [card(.ace, .hearts), card(.eight, .diamonds), card(.two, .clubs)],
            aggressor: true
        ),
        make(
            "flopped-straight",
            hole: [card(.king, .hearts), card(.queen, .diamonds)],
            flop: [card(.jack, .spades), card(.ten, .hearts), card(.nine, .clubs)],
            aggressor: true
        ),
        make(
            "short-stack-top-pair",
            hole: [card(.king, .clubs), card(.queen, .hearts)],
            flop: [card(.king, .diamonds), card(.eight, .spades), card(.two, .clubs)],
            hero: 75, opponent: 75
        ),
        make(
            "wet-board-weak-hand",
            hole: [card(.queen, .spades), card(.jack, .hearts)],
            flop: [card(.nine, .hearts), card(.eight, .hearts), card(.two, .clubs)],
            aggressor: true
        ),
        make(
            "dry-board-no-initiative",
            hole: [card(.king, .spades), card(.queen, .diamonds)],
            flop: [card(.ace, .hearts), card(.eight, .clubs), card(.two, .spades)]
        ),
        make(
            "monotone-made-flush",
            hole: [card(.queen, .clubs), card(.jack, .clubs)],
            flop: [card(.ace, .clubs), card(.eight, .clubs), card(.two, .clubs)]
        ),
        make(
            "board-only-pair",
            hole: [card(.queen, .diamonds), card(.jack, .hearts)],
            flop: [card(.nine, .spades), card(.nine, .hearts), card(.two, .clubs)]
        ),
        make(
            "expensive-flush-draw",
            hole: [card(.king, .hearts), card(.queen, .hearts)],
            flop: [card(.ace, .hearts), card(.nine, .hearts), card(.two, .clubs)],
            pot: 150, call: 50, hero: 500, opponent: 450
        ),
        make(
            "set-on-wet-board",
            hole: [card(.jack, .hearts), card(.jack, .clubs)],
            flop: [card(.jack, .spades), card(.nine, .hearts), card(.eight, .hearts)]
        ),
        make(
            "expensive-top-pair",
            hole: [card(.king, .spades), card(.queen, .hearts)],
            flop: [card(.king, .diamonds), card(.eight, .spades), card(.two, .clubs)],
            pot: 100, call: 60, hero: 400, opponent: 340
        ),
    ]

    private static func card(_ rank: Rank, _ suit: Suit) -> Card {
        Card(rank: rank, suit: suit)
    }

    private static func make(
        _ id: String, hole: [Card], flop: [Card],
        pot: Double = 100, call: Double = 0,
        hero: Double = 400, opponent: Double = 400, aggressor: Bool = false
    ) -> PracticeScenario {
        PracticeScenario(
            id: id, holeCards: hole, flop: flop,
            betting: BettingState(
                pot: pot, amountToCall: call, heroStack: hero,
                opponentStack: opponent, bigBlind: 10
            ),
            isPreflopAggressor: aggressor
        )
    }
}

public struct PracticeFeedback: Equatable, Sendable {
    public let scenarioID: String
    public let chosenChoice: PracticeChoice
    public let correctChoice: PracticeChoice
    public let isCorrect: Bool
    public let analysis: PostflopAnalysis
    public let explanation: String
}
