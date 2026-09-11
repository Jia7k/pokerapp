import Foundation
import PokerCore

public struct TableConfiguration: Codable, Equatable, Sendable {
    public let bankroll: Double
    public let pot: Double
    public let amountToCall: Double
    public let heroStack: Double
    public let opponentStack: Double
    public let bigBlind: Double
    public let heroStreetContribution: Double
    public let minimumRaiseIncrement: Double

    public init(bankroll: Double, betting: BettingState) {
        self.bankroll = bankroll
        pot = betting.pot
        amountToCall = betting.amountToCall
        heroStack = betting.heroStack
        opponentStack = betting.opponentStack
        bigBlind = betting.bigBlind
        heroStreetContribution = betting.heroStreetContribution
        minimumRaiseIncrement = betting.minimumRaiseIncrement
    }

    public var betting: BettingState {
        BettingState(
            pot: pot, amountToCall: amountToCall, heroStack: heroStack,
            opponentStack: opponentStack, bigBlind: bigBlind,
            heroStreetContribution: heroStreetContribution,
            minimumRaiseIncrement: minimumRaiseIncrement
        )
    }

    public func validate() throws {
        guard bankroll.isFinite, bankroll >= 0 else { throw StrategyInputError.invalidBankroll }
        try betting.validate()
    }
}

public enum TableInputError: Error, Equatable, CustomStringConvertible {
    case invalidNumber(String)
    public var description: String {
        switch self {
        case .invalidNumber(let field): "Enter a valid, nonnegative number for \(field.lowercased())."
        }
    }
}

public struct TableSetupDraft: Equatable, Sendable {
    public var bankroll: String
    public var pot: String
    public var amountToCall: String
    public var heroStack: String
    public var opponentStack: String
    public var bigBlind: String
    public var heroStreetContribution: String
    public var minimumRaiseIncrement: String

    public init(configuration: TableConfiguration) {
        bankroll = PokerFormat.editable(configuration.bankroll)
        pot = PokerFormat.editable(configuration.pot)
        amountToCall = PokerFormat.editable(configuration.amountToCall)
        heroStack = PokerFormat.editable(configuration.heroStack)
        opponentStack = PokerFormat.editable(configuration.opponentStack)
        bigBlind = PokerFormat.editable(configuration.bigBlind)
        heroStreetContribution = PokerFormat.editable(configuration.heroStreetContribution)
        minimumRaiseIncrement = PokerFormat.editable(configuration.minimumRaiseIncrement)
    }

    public func validated(locale: Locale = .current) throws -> TableConfiguration {
        func number(_ text: String, _ field: String) throws -> Double {
            guard let value = PokerFormat.parseChips(text, locale: locale) else {
                throw TableInputError.invalidNumber(field)
            }
            return value
        }
        let configuration = try TableConfiguration(
            bankroll: number(bankroll, "Bankroll"),
            betting: BettingState(
                pot: number(pot, "Pot"), amountToCall: number(amountToCall, "Amount to call"),
                heroStack: number(heroStack, "Your stack"), opponentStack: number(opponentStack, "Opponent stack"),
                bigBlind: number(bigBlind, "Big blind"),
                heroStreetContribution: number(heroStreetContribution, "Your street contribution"),
                minimumRaiseIncrement: number(minimumRaiseIncrement, "Minimum raise increment")
            )
        )
        try configuration.validate()
        return configuration
    }
}
