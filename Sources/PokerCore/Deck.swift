public struct Deck: Sendable {
    public static let allCards: [Card] = Rank.allCases.flatMap { rank in
        Suit.allCases.map { Card(rank: rank, suit: $0) }
    }

    public private(set) var cards: [Card]

    public init(excluding knownCards: [Card] = []) throws {
        cards = try Self.remaining(excluding: knownCards)
    }

    public static func remaining(excluding knownCards: [Card]) throws -> [Card] {
        let knownMask = try mask(validating: knownCards)
        return allCards.filter { knownMask & (UInt64(1) << $0.id) == 0 }
    }

    public mutating func draw() -> Card? { cards.popLast() }
    public mutating func shuffle() { cards.shuffle() }
    public mutating func shuffle<R: RandomNumberGenerator>(using generator: inout R) {
        cards.shuffle(using: &generator)
    }

    /// Every physical card has one bit; validation needs no heap-allocated set.
    static func mask(validating cards: [Card]) throws -> UInt64 {
        var mask: UInt64 = 0
        for card in cards {
            let bit = UInt64(1) << card.id
            guard mask & bit == 0 else { throw PokerInputError.duplicateCard(card) }
            mask |= bit
        }
        return mask
    }
}
