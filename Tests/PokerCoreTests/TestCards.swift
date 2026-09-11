import PokerCore

// Fixture notation only; application inputs use typed Rank/Suit values.
func cards(_ notation: String) -> [Card] {
    let ranks: [Character: Rank] = [
        "2": .two, "3": .three, "4": .four, "5": .five, "6": .six,
        "7": .seven, "8": .eight, "9": .nine, "T": .ten,
        "J": .jack, "Q": .queen, "K": .king, "A": .ace
    ]
    let suits: [Character: Suit] = ["s": .spades, "h": .hearts, "d": .diamonds, "c": .clubs]
    return notation.split(separator: " ").map {
        let token = Array($0)
        precondition(token.count == 2, "Invalid test fixture")
        return Card(rank: ranks[token[0]]!, suit: suits[token[1]]!)
    }
}
