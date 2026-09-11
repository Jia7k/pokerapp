import Foundation
import PokerCore

public enum PokerFormat {
    public static func chips(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "—" }
        if value > 0, value < 0.01 {
            return value.formatted(.number.precision(.significantDigits(1...3)))
        }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }

    public static func editable(_ value: Double, locale: Locale = .current) -> String {
        guard value.isFinite, value >= 0 else { return "" }
        // Preserve accepted precision when reopening settings, including tiny chip units.
        return value.formatted(.number.locale(locale).grouping(.never).precision(.significantDigits(1...17)))
    }

    public static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite, value >= 0 else { return "—" }
        if value > 0, value < 0.001 {
            return "<" + 0.001.formatted(.percent.precision(.fractionLength(1)))
        }
        return value.formatted(.percent.precision(.fractionLength(0...1)))
    }
    public static func ratio(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "—" }
        guard value.isFinite else { return "∞" }
        if value > 0, value < 0.1 {
            return "<" + 0.1.formatted(.number.precision(.fractionLength(1)))
        }
        return value.formatted(.number.precision(.fractionLength(1)))
    }
    public static func parseChips(_ text: String, locale: Locale = .current) -> Double? {
        let separator = locale.decimalSeparator ?? "."
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: separator, with: ".")
        var normalized = ""
        var decimalSeen = false
        var digitSeen = false
        for character in input {
            if character == "." {
                guard !decimalSeen else { return nil }
                decimalSeen = true
                normalized.append(".")
            } else if character.isNumber, let digit = character.wholeNumberValue, (0...9).contains(digit) {
                digitSeen = true
                normalized += String(digit)
            } else {
                return nil
            }
        }
        guard digitSeen, let value = Double(normalized), value.isFinite, value >= 0 else { return nil }
        return value
    }

    public static func street(_ street: Street?) -> String {
        switch street {
        case .preflop: "PREFLOP"
        case .flop: "FLOP"
        case .turn: "TURN"
        case .river: "RIVER"
        case nil: "YOUR NEXT MOVE"
        }
    }

    public static func cardName(_ card: Card) -> String {
        let rank: String
        switch card.rank {
        case .ace: rank = "Ace"
        case .king: rank = "King"
        case .queen: rank = "Queen"
        case .jack: rank = "Jack"
        default: rank = card.rank.symbol
        }
        let suit: String
        switch card.suit {
        case .spades: suit = "spades"
        case .hearts: suit = "hearts"
        case .diamonds: suit = "diamonds"
        case .clubs: suit = "clubs"
        }
        return "\(rank) of \(suit)"
    }

    public static func slotName(_ slot: CardSlot) -> String {
        switch slot {
        case .hole(let index): "Hole card \(index + 1)"
        case .flop(let index): "Flop card \(index + 1)"
        case .turn: "Turn"
        case .river: "River"
        }
    }

    public static func slotID(_ slot: CardSlot) -> String {
        switch slot {
        case .hole(let index): "hole.\(index)"
        case .flop(let index): "flop.\(index)"
        case .turn: "turn"
        case .river: "river"
        }
    }
}
