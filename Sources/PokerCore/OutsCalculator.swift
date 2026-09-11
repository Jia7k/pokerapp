public struct DrawOut: Equatable, Sendable {
    public let card: Card
    public let resultingHand: HandValue
}

public struct OutsReport: Equatable, Sendable {
    public let currentHand: HandValue
    public let street: Street
    public let outs: [DrawOut]
    public let unseenCardCount: Int

    public var count: Int { outs.count }
    public var cards: [Card] { outs.map(\.card) }

    /// Exact chance that the NEXT card is one of the listed completion cards.
    /// This is not showdown equity or an exact two-card probability.
    public var nextCardCompletionProbability: Double? {
        guard street == .flop || street == .turn, unseenCardCount > 0 else { return nil }
        return Double(count) / Double(unseenCardCount)
    }
}

public enum OutsCalculator {
    /// Enumerates potential made-hand outs: category upgrades to straight, flush,
    /// full house, quads, or straight flush. Unknown opponents may still beat them.
    /// Pair/trips improvements, better hands within the same category and backdoor
    /// two-card draws are intentionally outside this completion metric.
    public static func calculate(
        holeCards: [Card], board: [Card], deadCards: [Card] = []
    ) throws -> OutsReport {
        guard holeCards.count == 2 else {
            throw PokerInputError.invalidCardCount(actual: holeCards.count, expected: "2 hole cards")
        }
        guard (3...5).contains(board.count) else {
            throw PokerInputError.invalidCardCount(actual: board.count, expected: "3 to 5 board cards")
        }
        let knownCards = holeCards + board
        let unseen = try Deck.remaining(excluding: knownCards + deadCards)
        let currentHand = try HandEvaluator.evaluate(knownCards)
        let street: Street = board.count == 3 ? .flop : board.count == 4 ? .turn : .river
        var outs: [DrawOut] = []

        if street != .river {
            for candidate in unseen {
                let result = try HandEvaluator.evaluate(knownCards + [candidate])
                guard result.category >= .straight,
                      result.category > currentHand.category else { continue }

                // At the river, a shared board hand is not a personal draw out.
                // Compare the full value: a hole card may improve the SAME category.
                if board.count == 4 {
                    let boardValue = try HandEvaluator.evaluate(board + [candidate])
                    guard result > boardValue else { continue }
                }
                // One entry per physical card also deduplicates combined draws.
                outs.append(DrawOut(card: candidate, resultingHand: result))
            }
        }

        return OutsReport(
            currentHand: currentHand, street: street,
            outs: outs, unseenCardCount: unseen.count
        )
    }
}
