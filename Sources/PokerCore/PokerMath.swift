public enum Street: Sendable {
    case preflop, flop, turn, river
}

public enum PokerMath {
    /// Pot includes the opponent's outstanding bet, but not the hero's call.
    /// The result is a fraction in 0...1, not a percentage in 0...100.
    public static func requiredEquity(potBeforeCall: Double, callAmount: Double) throws -> Double {
        guard potBeforeCall.isFinite, callAmount.isFinite,
              potBeforeCall >= 0, callAmount >= 0 else {
            throw PokerInputError.invalidChipAmount
        }
        guard callAmount > 0 else { return 0 }
        let totalPot = potBeforeCall + callAmount
        // Equivalent ratio avoids overflow when both finite amounts are huge.
        if !totalPot.isFinite { return 1 / (potBeforeCall / callAmount + 1) }
        return callAmount / totalPot
    }

    /// Approximate draw-hit probability, NOT equity against an opponent.
    /// Flop assumes seeing both remaining cards; turn assumes seeing the river.
    /// Returns nil preflop/on the river, when this draw heuristic is inapplicable.
    public static func ruleOfTwoAndFour(outs: Int, street: Street) throws -> Double? {
        let maximumOuts: Int
        let multiplier: Int
        switch street {
        case .flop: (maximumOuts, multiplier) = (47, 4)
        case .turn: (maximumOuts, multiplier) = (46, 2)
        case .preflop, .river: (maximumOuts, multiplier) = (0, 0)
        }
        guard (0...maximumOuts).contains(outs) else {
            throw PokerInputError.invalidOutCount(outs)
        }
        guard multiplier > 0 else { return nil }
        return min(1, Double(outs * multiplier) / 100)
    }
}
