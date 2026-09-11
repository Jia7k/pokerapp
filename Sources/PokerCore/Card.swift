public enum Rank: Int, CaseIterable, Codable, Comparable, Sendable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace

    public var symbol: String {
        switch self {
        case .jack: "J"
        case .queen: "Q"
        case .king: "K"
        case .ace: "A"
        default: String(rawValue)
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum Suit: String, CaseIterable, Codable, Sendable {
    case spades = "♠", hearts = "♥", diamonds = "♦", clubs = "♣"

    var sortIndex: Int {
        switch self {
        case .spades: 0
        case .hearts: 1
        case .diamonds: 2
        case .clubs: 3
        }
    }
}

public struct Card: Hashable, Codable, Identifiable, Comparable, Sendable,
    CustomStringConvertible {
    public let rank: Rank
    public let suit: Suit

    public init(rank: Rank, suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    public var id: Int { (rank.rawValue - 2) * 4 + suit.sortIndex }
    public var description: String { rank.symbol + suit.rawValue }

    /// A stable display order only. Suits never break poker hand ties.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.id < rhs.id
    }
}
