import Observation

public enum CardSlot: Hashable, Sendable, CaseIterable {
    case hole(Int), flop(Int), turn, river
    public static let allCases: [CardSlot] = [.hole(0), .hole(1), .flop(0), .flop(1), .flop(2), .turn, .river]
}

public enum AnalysisStatus: Equatable, Sendable {
    case awaitingHoleCards, awaitingFlop, ready, invalidInput
}

/// One coherent derived snapshot; invalid/incomplete input never retains old advice.
public struct PokerAnalysis: Equatable, Sendable {
    public let status: AnalysisStatus
    public let message: String?
    public let street: Street?
    public let recommendation: ActionRecommendation?
    public let hand: HandValue?
    public let outs: OutsReport?
    public let texture: BoardTextureReport?
    public let requiredEquity: Double?
    public let approximateDrawProbability: Double?
    public let decisionDrawProbability: Double?
    public let effectiveStack: Double?
    public let stackToPotRatio: Double?
    public let chartDepth: StackDepth?

    init(
        status: AnalysisStatus, message: String? = nil, street: Street? = nil,
        recommendation: ActionRecommendation? = nil, hand: HandValue? = nil,
        outs: OutsReport? = nil, texture: BoardTextureReport? = nil,
        requiredEquity: Double? = nil, approximateDrawProbability: Double? = nil,
        decisionDrawProbability: Double? = nil, effectiveStack: Double? = nil,
        stackToPotRatio: Double? = nil, chartDepth: StackDepth? = nil
    ) {
        self.status = status
        self.message = message
        self.street = street
        self.recommendation = recommendation
        self.hand = hand
        self.outs = outs
        self.texture = texture
        self.requiredEquity = requiredEquity
        self.approximateDrawProbability = approximateDrawProbability
        self.decisionDrawProbability = decisionDrawProbability
        self.effectiveStack = effectiveStack
        self.stackToPotRatio = stackToPotRatio
        self.chartDepth = chartDepth
    }
}

@MainActor @Observable
public final class PokerViewModel {
    /// Session record only; editing advice does not move money or execute bets.
    public var bankroll: Double { didSet { recompute() } }
    public var betting: BettingState { didSet { recompute() } }
    public var position: Position { didSet { recompute() } }
    public var preflopSituation: PreflopSituation { didSet { recompute() } }
    public var isPreflopAggressor: Bool { didSet { recompute() } }
    public private(set) var holeCards: [Card?] = [nil, nil]
    public private(set) var boardCards: [Card?] = Array(repeating: nil, count: 5)
    public private(set) var analysis = PokerAnalysis(status: .awaitingHoleCards, message: "Select two hole cards.")
    @ObservationIgnored private var isResetting = false

    public init(
        bankroll: Double = 1_000, betting: BettingState = BettingState(),
        position: Position = .button, preflopSituation: PreflopSituation = .unopened,
        isPreflopAggressor: Bool = false
    ) {
        self.bankroll = bankroll
        self.betting = betting
        self.position = position
        self.preflopSituation = preflopSituation
        self.isPreflopAggressor = isPreflopAggressor
        recompute()
    }

    public var selectedCards: Set<Card> { Set((holeCards + boardCards).compactMap { $0 }) }

    public func card(at slot: CardSlot) throws -> Card? {
        let location = try location(for: slot)
        return location.isHole ? holeCards[location.index] : boardCards[location.index]
    }

    public func availableCards(for slot: CardSlot) throws -> [Card] {
        var used = selectedCards
        if let current = try card(at: slot) { used.remove(current) }
        return Deck.allCards.filter { !used.contains($0) }
    }

    /// Rejections are atomic. Removing an earlier board street removes later streets.
    public func setCard(_ card: Card?, at slot: CardSlot) throws {
        let location = try location(for: slot)
        let current = try self.card(at: slot)
        if let card, card != current, selectedCards.contains(card) {
            throw PokerInputError.duplicateCard(card)
        }
        if !location.isHole, card != nil, location.index >= 3 {
            guard boardCards.prefix(location.index).allSatisfy({ $0 != nil }) else {
                throw StrategyInputError.earlierStreetIncomplete
            }
        }
        if location.isHole {
            holeCards[location.index] = card
        } else {
            var updated = boardCards
            updated[location.index] = card
            if card == nil {
                if location.index < 3 { updated[3] = nil; updated[4] = nil }
                if location.index == 3 { updated[4] = nil }
            }
            boardCards = updated
        }
        recompute()
    }

    /// Start input for another hand. The user remains responsible for recording
    /// actual chip movements; advice never silently changes balances.
    public func resetHand() {
        isResetting = true
        holeCards = [nil, nil]
        boardCards = Array(repeating: nil, count: 5)
        betting = BettingState(
            heroStack: betting.heroStack, opponentStack: betting.opponentStack,
            bigBlind: betting.bigBlind
        )
        preflopSituation = .unopened
        isPreflopAggressor = false
        isResetting = false
        recompute()
    }

    public func recompute() {
        guard !isResetting else { return }
        do {
            guard bankroll.isFinite, bankroll >= 0 else { throw StrategyInputError.invalidBankroll }
            try betting.validate()
            let hole = holeCards.compactMap { $0 }
            guard hole.count == 2 else {
                analysis = PokerAnalysis(
                    status: .awaitingHoleCards,
                    message: hole.isEmpty ? "Select two hole cards." : "Select one more hole card."
                )
                return
            }
            let board = boardCards.compactMap { $0 }
            if board.isEmpty {
                let (recommendation, depth) = try preflopRecommendation(holeCards: hole)
                analysis = PokerAnalysis(
                    status: .ready, street: .preflop, recommendation: recommendation,
                    requiredEquity: try betting.requiredEquity(), effectiveStack: betting.effectiveStack,
                    stackToPotRatio: betting.stackToPotRatio, chartDepth: depth
                )
                return
            }
            guard boardCards.prefix(3).allSatisfy({ $0 != nil }) else {
                analysis = PokerAnalysis(status: .awaitingFlop, message: "Complete all three flop cards.")
                return
            }
            let result = try PostflopHeuristicEngine.analyze(
                holeCards: hole, board: board, betting: betting,
                isPreflopAggressor: isPreflopAggressor
            )
            analysis = PokerAnalysis(
                status: .ready, street: result.outs.street,
                recommendation: result.recommendation, hand: result.madeHand.value,
                outs: result.outs, texture: result.texture,
                requiredEquity: try betting.requiredEquity(),
                approximateDrawProbability: result.approximateDrawProbability,
                decisionDrawProbability: result.decisionDrawProbability,
                effectiveStack: betting.effectiveStack,
                stackToPotRatio: betting.stackToPotRatio
            )
        } catch {
            analysis = PokerAnalysis(status: .invalidInput, message: String(describing: error))
        }
    }

    private func location(for slot: CardSlot) throws -> (isHole: Bool, index: Int) {
        switch slot {
        case .hole(let index) where (0..<2).contains(index): return (true, index)
        case .flop(let index) where (0..<3).contains(index): return (false, index)
        case .turn: return (false, 3)
        case .river: return (false, 4)
        default: throw StrategyInputError.invalidCardSlot
        }
    }

    private func preflopRecommendation(holeCards: [Card]) throws -> (ActionRecommendation, StackDepth?) {
        if betting.heroStack == 0 {
            return (ActionRecommendation(action: .noAction, reason: .alreadyAllIn, explanation: "Hero is already all-in."), nil)
        }
        if betting.opponentStack == 0, betting.amountToCall == 0 {
            return (ActionRecommendation(action: .check, reason: .opponentAllIn, explanation: "No further matched betting is possible."), nil)
        }
        let currentBet = betting.heroStreetContribution + betting.amountToCall
        switch preflopSituation {
        case .unopened:
            guard currentBet <= betting.bigBlind,
                  position != .bigBlind || betting.amountToCall == 0 else {
                throw StrategyInputError.incompatiblePreflopSituation
            }
        case .facingOpenRaise:
            guard betting.amountToCall > 0, currentBet > betting.bigBlind else {
                throw StrategyInputError.incompatiblePreflopSituation
            }
        }
        // Include hero's already-posted blind in the starting-depth estimate.
        // Divide before adding to preserve a representable ratio when the sum
        // of chip amounts would overflow. Values outside the chart use endpoints.
        let effectiveBigBlinds = betting.effectiveStack / betting.bigBlind
            + betting.heroStreetContribution / betting.bigBlind
        let boundedBigBlinds = max(20, min(100, effectiveBigBlinds))
        let depth = try StackDepth.nearest(to: boundedBigBlinds)
        let hand = try StartingHand(holeCards: holeCards)
        let intent = PreflopStrategy.action(position: position, hand: hand, depth: depth, situation: preflopSituation)
        let action: PokerAction
        switch intent {
        case .fold: action = betting.amountToCall == 0 ? .check : .fold
        case .check: action = .check
        case .call: action = betting.passiveAction()
        case .raise(let bigBlinds): action = try sizeChartRaise(base: betting.bigBlind, multiplier: bigBlinds)
        case .threeBet(let multiplier): action = try sizeChartRaise(base: currentBet, multiplier: multiplier)
        }
        let notes = [
            "Simplified GTO-inspired six-seat preset; not solver-derived strategy.",
            "Uses the nearest \(depth.rawValue) BB chart. Opener ranges, limpers, re-raised pots and multiway pots are not modeled."
        ]
        return (ActionRecommendation(
            action: action, reason: .preflopChart,
            explanation: "The \(position.name) \(depth.rawValue) BB preset selects \(hand.notation). Sizing accounts for current bets and stack coverage.",
            notes: notes
        ), depth)
    }

    private func sizeChartRaise(base: Double, multiplier: Double) throws -> PokerAction {
        if betting.effectiveStack <= betting.callCost { return betting.passiveAction() }
        let desiredTotal = base * multiplier
        // The sizing intent can overflow even when the covered wager is small.
        guard desiredTotal.isFinite else { return try betting.commitEffectiveStack() }
        return try betting.sizedRaise(to: desiredTotal)
    }
}
