public enum StrategyInputError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidBettingState(String)
    case invalidBankroll
    case invalidCardSlot
    case earlierStreetIncomplete
    case incompatiblePreflopSituation

    public var description: String {
        switch self {
        case .invalidBettingState(let message): message
        case .invalidBankroll: "Enter a finite, nonnegative bankroll."
        case .invalidCardSlot: "That card slot does not exist."
        case .earlierStreetIncomplete: "Complete the earlier community-card street first."
        case .incompatiblePreflopSituation: "The call amount and current bet do not match the selected preflop situation."
        }
    }
}

public enum PokerAction: Equatable, Sendable {
    case noAction, fold, check
    case call(amount: Double)
    case bet(amount: Double)
    /// Total chips committed by hero on this street, including prior contributions.
    case raise(to: Double)
    /// Additional chips equal to hero's entire remaining stack.
    case allIn(amount: Double)
}

public enum RecommendationReason: String, Sendable {
    case preflopChart, shortStackValue, madeHandValue, drawPriceAcceptable
    case drawTooExpensive, dryBoardContinuationBet, checkWithoutValue
    case alreadyAllIn, opponentAllIn, boardOnlyHand, insufficientCoverage, guaranteedSplit
}

public struct ActionRecommendation: Equatable, Sendable {
    public let action: PokerAction
    public let reason: RecommendationReason
    public let explanation: String
    public let notes: [String]

    public init(action: PokerAction, reason: RecommendationReason, explanation: String, notes: [String] = []) {
        self.action = action
        self.reason = reason
        self.explanation = explanation
        self.notes = notes
    }
}

/// Heads-up chip state. Stacks are chips behind, after prior bets.
public struct BettingState: Equatable, Sendable {
    public var pot: Double
    public var amountToCall: Double
    public var heroStack: Double
    public var opponentStack: Double
    public var bigBlind: Double
    public var heroStreetContribution: Double
    public var minimumRaiseIncrement: Double

    public init(
        pot: Double = 0, amountToCall: Double = 0,
        heroStack: Double = 1_000, opponentStack: Double = 1_000,
        bigBlind: Double = 10, heroStreetContribution: Double = 0,
        minimumRaiseIncrement: Double? = nil
    ) {
        self.pot = pot
        self.amountToCall = amountToCall
        self.heroStack = heroStack
        self.opponentStack = opponentStack
        self.bigBlind = bigBlind
        self.heroStreetContribution = heroStreetContribution
        self.minimumRaiseIncrement = minimumRaiseIncrement ?? bigBlind
    }

    public var effectiveStack: Double { min(heroStack, opponentStack + amountToCall) }
    public var callCost: Double { min(heroStack, amountToCall) }
    /// Opponent overbets beyond a short hero stack are not part of the callable pot.
    public var contestablePot: Double {
        // Subtract the large outstanding amount before adding the small matched
        // call; pot - (amountToCall - callCost) can round the matched chips away.
        callCost < amountToCall ? (pot - amountToCall) + callCost : pot
    }
    public var stackToPotRatio: Double? { pot > 0 ? effectiveStack / pot : nil }
    public var closesBettingByCalling: Bool { callCost > 0 && (callCost == heroStack || opponentStack == 0) }

    public func validate() throws {
        let amounts = [pot, amountToCall, heroStack, opponentStack, heroStreetContribution]
        guard amounts.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw StrategyInputError.invalidBettingState("Chip amounts must be finite and nonnegative.")
        }
        guard bigBlind.isFinite, bigBlind > 0,
              minimumRaiseIncrement.isFinite, minimumRaiseIncrement >= bigBlind else {
            throw StrategyInputError.invalidBettingState("Use a positive big blind and a minimum raise increment at least that large.")
        }
        let currentBet = heroStreetContribution + amountToCall
        guard currentBet.isFinite, pot >= currentBet else {
            throw StrategyInputError.invalidBettingState("The pot must include the existing contribution and outstanding bet.")
        }
    }

    public func requiredEquity() throws -> Double {
        try validate()
        return try PokerMath.requiredEquity(potBeforeCall: contestablePot, callAmount: callCost)
    }

    /// Use after validating the state. No extra chips are committed by this helper.
    public func passiveAction() -> PokerAction {
        if heroStack == 0 { return .noAction }
        if callCost == 0 { return .check }
        return callCost == heroStack ? .allIn(amount: callCost) : .call(amount: callCost)
    }

    public func sizedBet(potFraction: Double) throws -> PokerAction {
        guard potFraction.isFinite, potFraction > 0 else {
            throw StrategyInputError.invalidBettingState("A bet fraction must be positive and finite.")
        }
        return try bet(amount: max(bigBlind, pot * potFraction))
    }

    public func sizedRaise(to total: Double) throws -> PokerAction {
        try validate()
        guard total.isFinite, total > 0 else {
            throw StrategyInputError.invalidBettingState("A raise total must be positive and finite.")
        }
        if heroStack == 0 { return .noAction }
        let minimumTotal = heroStreetContribution + amountToCall + minimumRaiseIncrement
        let desiredCost = max(total, minimumTotal) - heroStreetContribution
        let cost = min(effectiveStack, desiredCost)
        guard cost > callCost else { return passiveAction() }
        if cost == heroStack { return .allIn(amount: cost) }
        // A short raise is allowed only when hero is actually all-in. Do not
        // recommend an illegal under-raise just because the opponent is short.
        let matchedTotal = heroStreetContribution + cost
        guard matchedTotal.isFinite, matchedTotal >= minimumTotal else { return passiveAction() }
        return .raise(to: matchedTotal)
    }

    public func commitEffectiveStack() throws -> PokerAction {
        try validate()
        if heroStack == 0 { return .noAction }
        // An all-in uses additional chips; no potentially overflowing total
        // street contribution is needed when the entire hero stack is covered.
        if effectiveStack == heroStack { return .allIn(amount: heroStack) }
        if amountToCall > 0 {
            if effectiveStack <= callCost { return passiveAction() }
            let coveredTotal = heroStreetContribution + effectiveStack
            guard coveredTotal.isFinite else { return passiveAction() }
            return try sizedRaise(to: coveredTotal)
        }
        return try bet(amount: effectiveStack)
    }

    private func bet(amount target: Double) throws -> PokerAction {
        try validate()
        guard amountToCall == 0 else {
            throw StrategyInputError.invalidBettingState("Facing a bet requires a call or raise, not a new bet.")
        }
        if heroStack == 0 { return .noAction }
        let amount = min(target, effectiveStack)
        guard amount > 0 else { return .check }
        if amount == heroStack { return .allIn(amount: amount) }
        guard amount >= bigBlind else { return .check }
        return .bet(amount: amount)
    }
}
