public enum HandCategory: Int, CaseIterable, Comparable, Sendable {
    case highCard, onePair, twoPair, threeOfAKind, straight
    case flush, fullHouse, fourOfAKind, straightFlush

    public var name: String {
        switch self {
        case .highCard: "High Card"
        case .onePair: "One Pair"
        case .twoPair: "Two Pair"
        case .threeOfAKind: "Three of a Kind"
        case .straight: "Straight"
        case .flush: "Flush"
        case .fullHouse: "Full House"
        case .fourOfAKind: "Four of a Kind"
        case .straightFlush: "Straight Flush"
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Absolute showdown strength, not equity against an opponent's range.
public struct HandValue: Hashable, Comparable, Sendable {
    public let category: HandCategory
    /// Most significant first: e.g. full house = [trip rank, pair rank].
    public let tiebreakers: [Rank]

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        return lhs.tiebreakers.lexicographicallyPrecedes(rhs.tiebreakers)
    }
}

public enum HandEvaluator {
    /// Returns the best five-card value among 5, 6, or 7 unique cards.
    public static func evaluate(_ cards: [Card]) throws -> HandValue {
        guard (5...7).contains(cards.count) else {
            throw PokerInputError.invalidCardCount(actual: cards.count, expected: "5 to 7 cards")
        }
        _ = try Deck.mask(validating: cards)
        if cards.count == 5 { return evaluateFive(cards) }

        var best: HandValue?
        let count = cards.count
        // Six cards have 6 subsets; seven cards have 21. Hold'em may use zero,
        // one, or two hole cards, so every five-card subset is eligible.
        for a in 0..<(count - 4) {
            for b in (a + 1)..<(count - 3) {
                for c in (b + 1)..<(count - 2) {
                    for d in (c + 1)..<(count - 1) {
                        for e in (d + 1)..<count {
                            let value = evaluateFive([cards[a], cards[b], cards[c], cards[d], cards[e]])
                            if best == nil || value > best! { best = value }
                        }
                    }
                }
            }
        }
        // The validated card count guarantees at least one five-card subset.
        return best!
    }

    private static func evaluateFive(_ cards: [Card]) -> HandValue {
        let ranks = cards.map(\.rank).sorted(by: >)
        var counts = [Int](repeating: 0, count: 15)
        for rank in ranks { counts[rank.rawValue] += 1 }
        let groups = Rank.allCases
            .filter { counts[$0.rawValue] > 0 }
            .sorted {
                let lhsCount = counts[$0.rawValue]
                let rhsCount = counts[$1.rawValue]
                return lhsCount == rhsCount ? $0 > $1 : lhsCount > rhsCount
            }

        let flush = cards.dropFirst().allSatisfy { $0.suit == cards[0].suit }
        let straightHigh: Rank?
        if groups.count == 5, ranks[0].rawValue - ranks[4].rawValue == 4 {
            straightHigh = ranks[0]
        } else if ranks == [.ace, .five, .four, .three, .two] {
            straightHigh = .five
        } else {
            straightHigh = nil
        }

        if flush, let straightHigh {
            return HandValue(category: .straightFlush, tiebreakers: [straightHigh])
        }
        if counts[groups[0].rawValue] == 4 {
            return HandValue(category: .fourOfAKind, tiebreakers: groups)
        }
        if counts[groups[0].rawValue] == 3, counts[groups[1].rawValue] == 2 {
            return HandValue(category: .fullHouse, tiebreakers: groups)
        }
        if flush { return HandValue(category: .flush, tiebreakers: ranks) }
        if let straightHigh {
            return HandValue(category: .straight, tiebreakers: [straightHigh])
        }
        if counts[groups[0].rawValue] == 3 {
            return HandValue(category: .threeOfAKind, tiebreakers: groups)
        }
        if counts[groups[0].rawValue] == 2 {
            let category: HandCategory = counts[groups[1].rawValue] == 2 ? .twoPair : .onePair
            return HandValue(category: category, tiebreakers: groups)
        }
        return HandValue(category: .highCard, tiebreakers: ranks)
    }
}
