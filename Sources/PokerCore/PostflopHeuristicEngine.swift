public enum BoardTexture: String, Sendable {
    case dryRainbow, wetConnected, monotone
}

public struct BoardTextureReport: Equatable, Sendable {
    public let texture: BoardTexture
    public let isPaired: Bool
    public let maximumSuitCount: Int
    public let isConnected: Bool

    public init(
        texture: BoardTexture, isPaired: Bool,
        maximumSuitCount: Int, isConnected: Bool
    ) {
        self.texture = texture
        self.isPaired = isPaired
        self.maximumSuitCount = maximumSuitCount
        self.isConnected = isConnected
    }
}

public enum BoardTextureAnalyzer {
    public static func analyze(_ board: [Card]) throws -> BoardTextureReport {
        guard (3...5).contains(board.count) else {
            throw PokerInputError.invalidCardCount(
                actual: board.count, expected: "3 to 5 board cards"
            )
        }
        _ = try Deck.mask(validating: board)

        var suitCounts: [Suit: Int] = [:]
        var rankCounts: [Rank: Int] = [:]
        for card in board {
            suitCounts[card.suit, default: 0] += 1
            rankCounts[card.rank, default: 0] += 1
        }
        let maximumSuitCount = suitCounts.values.max() ?? 0
        let isPaired = rankCounts.values.contains { $0 >= 2 }
        let ranks = Set(board.map(\.rank))
        let straightWindows: [Set<Rank>] = [
            [.ace, .two, .three, .four, .five],
            [.two, .three, .four, .five, .six],
            [.three, .four, .five, .six, .seven],
            [.four, .five, .six, .seven, .eight],
            [.five, .six, .seven, .eight, .nine],
            [.six, .seven, .eight, .nine, .ten],
            [.seven, .eight, .nine, .ten, .jack],
            [.eight, .nine, .ten, .jack, .queen],
            [.nine, .ten, .jack, .queen, .king],
            [.ten, .jack, .queen, .king, .ace],
        ]
        let isConnected = straightWindows.contains { ranks.intersection($0).count >= 3 }
        let texture: BoardTexture
        if maximumSuitCount == board.count {
            texture = .monotone
        } else if maximumSuitCount >= 2 || isConnected {
            texture = .wetConnected
        } else {
            texture = .dryRainbow
        }
        return BoardTextureReport(
            texture: texture, isPaired: isPaired,
            maximumSuitCount: maximumSuitCount, isConnected: isConnected
        )
    }
}

public struct MadeHandAssessment: Equatable, Sendable {
    public let value: HandValue
    public let hasTopPairOrBetter: Bool
    public let isStrongMadeHand: Bool
    public let playsBoard: Bool

    public init(
        value: HandValue, hasTopPairOrBetter: Bool,
        isStrongMadeHand: Bool, playsBoard: Bool
    ) {
        self.value = value
        self.hasTopPairOrBetter = hasTopPairOrBetter
        self.isStrongMadeHand = isStrongMadeHand
        self.playsBoard = playsBoard
    }
}

public struct PostflopAnalysis: Equatable, Sendable {
    public let texture: BoardTextureReport
    public let madeHand: MadeHandAssessment
    public let outs: OutsReport
    /// Rule-of-2/4 completion estimate. It is not win equity.
    public let approximateDrawProbability: Double?
    /// Completion estimate for the cards guaranteed by calling now.
    public let decisionDrawProbability: Double?
    public let recommendation: ActionRecommendation

    public init(
        texture: BoardTextureReport, madeHand: MadeHandAssessment,
        outs: OutsReport, approximateDrawProbability: Double?,
        decisionDrawProbability: Double?, recommendation: ActionRecommendation
    ) {
        self.texture = texture
        self.madeHand = madeHand
        self.outs = outs
        self.approximateDrawProbability = approximateDrawProbability
        self.decisionDrawProbability = decisionDrawProbability
        self.recommendation = recommendation
    }
}

public enum PostflopHeuristicEngine {
    public static func analyze(
        holeCards: [Card], board: [Card], betting: BettingState,
        isPreflopAggressor: Bool
    ) throws -> PostflopAnalysis {
        try betting.validate()
        let texture = try BoardTextureAnalyzer.analyze(board)
        let outs = try OutsCalculator.calculate(holeCards: holeCards, board: board)
        let madeHandContext = try assessMadeHand(
            value: outs.currentHand, holeCards: holeCards, board: board
        )
        let madeHand = madeHandContext.assessment
        let guaranteedSplit = try isGuaranteedSplit(
            holeCards: holeCards, board: board, madeHand: madeHand
        )
        let approximateProbability = try PokerMath.ruleOfTwoAndFour(
            outs: outs.count, street: outs.street
        )
        let decisionProbability: Double?
        if betting.amountToCall == 0 || outs.street == .river {
            decisionProbability = nil
        } else if outs.street == .flop, betting.closesBettingByCalling {
            decisionProbability = approximateProbability
        } else {
            decisionProbability = outs.nextCardCompletionProbability
        }

        let recommendation = try recommend(
            texture: texture, madeHand: madeHand, outs: outs,
            heroContributesToCategory: madeHandContext.heroContributesToCategory,
            guaranteedSplit: guaranteedSplit,
            decisionDrawProbability: decisionProbability,
            betting: betting, isPreflopAggressor: isPreflopAggressor
        )
        return PostflopAnalysis(
            texture: texture, madeHand: madeHand, outs: outs,
            approximateDrawProbability: approximateProbability,
            decisionDrawProbability: decisionProbability,
            recommendation: recommendation
        )
    }

    private static func assessMadeHand(
        value: HandValue, holeCards: [Card], board: [Card]
    ) throws -> (assessment: MadeHandAssessment, heroContributesToCategory: Bool) {
        let boardValue = board.count == 5 ? try HandEvaluator.evaluate(board) : nil
        let playsBoard = boardValue == value
        let holeRanks = Set(holeCards.map(\.rank))
        let contributesToCategory: Bool

        switch value.category {
        case .highCard:
            contributesToCategory = false
        case .onePair:
            contributesToCategory = value.tiebreakers.first.map(holeRanks.contains) ?? false
        case .twoPair:
            contributesToCategory = !playsBoard && !holeRanks.isDisjoint(with: value.tiebreakers.prefix(2))
        case .threeOfAKind, .fourOfAKind:
            contributesToCategory = !playsBoard && value.tiebreakers.first.map(holeRanks.contains) ?? false
        case .fullHouse:
            contributesToCategory = !playsBoard && !holeRanks.isDisjoint(with: value.tiebreakers.prefix(2))
        case .straight, .flush, .straightFlush:
            contributesToCategory = !playsBoard
        }

        let hasTopPairOrBetter: Bool
        if value.category == .onePair,
           let pairRank = value.tiebreakers.first,
           let highestBoardRank = board.map(\.rank).max() {
            hasTopPairOrBetter = contributesToCategory && pairRank >= highestBoardRank
        } else {
            hasTopPairOrBetter = value.category >= .twoPair && contributesToCategory
        }
        let isStrongMadeHand = value.category >= .twoPair && contributesToCategory
        return (
            MadeHandAssessment(
                value: value, hasTopPairOrBetter: hasTopPairOrBetter,
                isStrongMadeHand: isStrongMadeHand, playsBoard: playsBoard
            ),
            contributesToCategory
        )
    }

    private static func recommend(
        texture: BoardTextureReport, madeHand: MadeHandAssessment,
        outs: OutsReport, heroContributesToCategory: Bool,
        guaranteedSplit: Bool,
        decisionDrawProbability: Double?,
        betting: BettingState, isPreflopAggressor: Bool
    ) throws -> ActionRecommendation {
        let notes = [
            "This is a simplified heads-up heuristic, not an opponent range model.",
            "Draw completion probabilities are not true win equity.",
        ]

        if betting.heroStack == 0 {
            return ActionRecommendation(
                action: .noAction, reason: .alreadyAllIn,
                explanation: "Hero has no chips left to act.", notes: notes
            )
        }
        if betting.amountToCall == 0, betting.opponentStack == 0 {
            return ActionRecommendation(
                action: .check, reason: .opponentAllIn,
                explanation: "No call is required and the opponent is all-in.", notes: notes
            )
        }
        if guaranteedSplit {
            let action = betting.passiveAction()
            let explanation = betting.amountToCall > 0
                ? "Call because every legal opponent hand must split this pot."
                : "Check because every legal opponent hand must split this pot."
            return ActionRecommendation(
                action: action, reason: .guaranteedSplit,
                explanation: explanation, notes: notes
            )
        }
        if let spr = betting.stackToPotRatio,
           spr < 1, madeHand.hasTopPairOrBetter {
            let action = try betting.commitEffectiveStack()
            return ActionRecommendation(
                action: action, reason: .shortStackValue,
                explanation: commitmentExplanation(for: action), notes: notes
            )
        }

        if betting.amountToCall > 0 {
            if madeHand.isStrongMadeHand {
                return ActionRecommendation(
                    action: betting.passiveAction(), reason: .madeHandValue,
                    explanation: "Continue with a hero-made two-pair-or-better hand.", notes: notes
                )
            }

            let requiredEquity = try betting.requiredEquity()
            if madeHand.hasTopPairOrBetter {
                if requiredEquity <= 1.0 / 3.0 {
                    return ActionRecommendation(
                        action: betting.passiveAction(), reason: .madeHandValue,
                        explanation: "Continue with top pair at one-third pot odds or better.", notes: notes
                    )
                }
                return ActionRecommendation(
                    action: .fold, reason: .drawTooExpensive,
                    explanation: "Fold top pair when the required equity exceeds this heuristic's one-third limit.",
                    notes: notes
                )
            }

            if let probability = decisionDrawProbability,
               probability > 0, probability >= requiredEquity {
                return ActionRecommendation(
                    action: betting.passiveAction(), reason: .drawPriceAcceptable,
                    explanation: "The draw completion estimate covers the required pot odds.", notes: notes
                )
            }
            return ActionRecommendation(
                action: .fold, reason: .drawTooExpensive,
                explanation: "The available draw estimate does not cover the required pot odds.", notes: notes
            )
        }

        if outs.street == .flop,
           texture.texture == .dryRainbow,
           isPreflopAggressor {
            let action = try betting.sizedBet(potFraction: 0.33)
            return sizedBetRecommendation(
                action: action, reason: .dryBoardContinuationBet,
                explanation: "Use a small continuation bet on this dry flop.", notes: notes
            )
        }
        if madeHand.isStrongMadeHand {
            let action = try betting.sizedBet(potFraction: 0.66)
            return sizedBetRecommendation(
                action: action, reason: .madeHandValue,
                explanation: "Bet for value with a hero-made two-pair-or-better hand.", notes: notes
            )
        }
        if madeHand.playsBoard ||
            (madeHand.value.category >= .onePair && !heroContributesToCategory) {
            return ActionRecommendation(
                action: .check, reason: .boardOnlyHand,
                explanation: "Check because the made-hand category comes from the board.", notes: notes
            )
        }
        return ActionRecommendation(
            action: .check, reason: .checkWithoutValue,
            explanation: "Check without enough made-hand value for this heuristic.", notes: notes
        )
    }

    private static func commitmentExplanation(for action: PokerAction) -> String {
        switch action {
        case .allIn:
            "Commit the remaining hero stack with short-stack value."
        case .call:
            "Call the opponent's remaining effective wager with short-stack value."
        case .bet:
            "Bet the opponent-covered effective amount with short-stack value."
        case .raise:
            "Raise to the effective commitment amount with short-stack value."
        case .check:
            "Check because no legal effective-stack wager is available."
        case .noAction:
            "No further action is available."
        case .fold:
            "Fold."
        }
    }

    private static func sizedBetRecommendation(
        action: PokerAction, reason: RecommendationReason,
        explanation: String, notes: [String]
    ) -> ActionRecommendation {
        if action == .check {
            return ActionRecommendation(
                action: .check, reason: .insufficientCoverage,
                explanation: "Check because opponent coverage is below the legal minimum bet.",
                notes: notes
            )
        }
        return ActionRecommendation(
            action: action, reason: reason, explanation: explanation, notes: notes
        )
    }

    private static func isGuaranteedSplit(
        holeCards: [Card], board: [Card], madeHand: MadeHandAssessment
    ) throws -> Bool {
        guard board.count == 5, madeHand.playsBoard else { return false }
        let remaining = try Deck.remaining(excluding: holeCards + board)
        for first in 0..<(remaining.count - 1) {
            for second in (first + 1)..<remaining.count {
                let opponentValue = try HandEvaluator.evaluate(
                    board + [remaining[first], remaining[second]]
                )
                if opponentValue != madeHand.value { return false }
            }
        }
        return true
    }
}
