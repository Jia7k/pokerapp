/// A bounded shuffled curriculum; every round includes all topics plus
/// at most three reviews of concepts with an active error weight.
struct PracticeScenarioGenerator {
    private static let faceRanks: [Rank] = [.jack, .queen, .king]
    private static let lowRanks = Rank.allCases.filter { $0 < .jack }
    private var random: SplitMix64
    private var topics: [PracticeTopic] = []
    private var nextOrdinal: UInt64 = 1

    init(seed: UInt64) { random = SplitMix64(state: seed) }

    mutating func next(progress: PracticeLearningProgress = .init()) throws -> PreparedPracticeScenario {
        if topics.isEmpty { refillTopics(progress: progress) }
        guard let topic = topics.popLast() else { throw PracticeGenerationError.emptyCoverage }
        let id = "generated-\(nextOrdinal)"
        if nextOrdinal < .max { nextOrdinal += 1 }

        for _ in 0..<8 {
            do {
                let candidate = try makeScenario(topic: topic, id: id, constructive: false)
                let prepared = try PreparedPracticeScenario(candidate)
                // Check the actual engine reason, not the explicit curriculum tag.
                if PreparedPracticeScenario.inferTopic(scenario: candidate, analysis: prepared.analysis) == topic {
                    return prepared
                }
            } catch PracticeGenerationError.unavailableCard {
                continue
            } catch PracticePreparationError.unsupportedChoice {
                continue
            }
        }
        return try constructiveFallback(for: topic, id: id)
    }

    /// Directly testable last resort: fresh suits, stacks and pots, with a card
    /// construction that guarantees the selected concept under the shared engine.
    mutating func constructiveFallback(for topic: PracticeTopic, id: String) throws -> PreparedPracticeScenario {
        let scenario = try makeScenario(topic: topic, id: id, constructive: true)
        let prepared = try PreparedPracticeScenario(scenario)
        guard PreparedPracticeScenario.inferTopic(scenario: scenario, analysis: prepared.analysis) == topic else {
            throw PracticeGenerationError.unconfirmedTopic
        }
        return prepared
    }

    private mutating func refillTopics(progress: PracticeLearningProgress) {
        topics = PracticeTopic.allCases
        let weights = PracticeTopic.allCases.map { progress.reviewWeight(for: $0) }
        let total = weights.reduce(0, +)
        if total > 0, total.isFinite {
            for _ in 0..<3 {
                var threshold = Double.random(in: 0..<total, using: &random)
                var selected: PracticeTopic?
                for (topic, weight) in zip(PracticeTopic.allCases, weights) where weight > 0 {
                    selected = topic
                    threshold -= weight
                    if threshold < 0 { break }
                }
                // The last positive entry also covers floating-point rounding
                // at the end of the cumulative distribution.
                if let selected { topics.append(selected) }
            }
        }
        topics.shuffle(using: &random)
    }

    private mutating func makeScenario(topic: PracticeTopic, id: String, constructive: Bool) throws -> PracticeScenario {
        let deal: Deal
        let betting: BettingState
        let aggressor: Bool
        switch topic {
        case .continuationBet:
            let hole = randomHoleCards()
            let ranks: [Rank] = constructive ? [.eight, .four, .two] : pick([
                [.ace, .eight, .two], [.king, .seven, .two], [.queen, .eight, .three],
                [.jack, .six, .two], [.ten, .six, .two]
            ])
            deal = Deal(hole: hole, flop: try board(ranks, excluding: hole, rainbow: true))
            betting = try deepBetting(fraction: 0)
            aggressor = true
        case .checking:
            let hole = randomHoleCards()
            if constructive {
                deal = Deal(hole: hole, flop: try board([.two, .four, .seven], excluding: hole, rainbow: true))
            } else {
                var deck = try Deck(excluding: hole)
                deck.shuffle(using: &random)
                deal = Deal(hole: hole, flop: Array(deck.cards.prefix(3)))
            }
            betting = try deepBetting(fraction: 0)
            aggressor = false
        case .shortStack:
            deal = try topPairDeal()
            betting = try shortStackBetting(mode: constructive ? 0 : pick([0, 1, 2, 3]))
            aggressor = Bool.random(using: &random)
        case .valueBet:
            deal = try valueDeal(kind: constructive ? 0 : pick([0, 1, 2, 3]))
            betting = try deepBetting(fraction: 0)
            aggressor = false
        case .drawPrice:
            deal = try drawDeal(kind: constructive ? 0 : pick([0, 1, 2]), constructive: constructive)
            let fraction = pick([0.25, 0.33, 0.5, 0.75, 1.0, 1.5])
            betting = try deepBetting(fraction: fraction, opponentAllIn: !constructive && Int.random(in: 0..<5, using: &random) == 0)
            aggressor = Bool.random(using: &random)
        case .facingBet:
            switch constructive ? 0 : pick([0, 1, 2]) {
            case 0: deal = try topPairDeal()
            case 1: deal = try valueDeal(kind: pick([0, 1, 2, 3]))
            default:
                let hole = randomHoleCards(distinctRanks: true)
                deal = Deal(hole: hole, flop: try board([.two, .four, .seven], excluding: hole, rainbow: true))
            }
            betting = try deepBetting(fraction: pick([0.25, 0.33, 0.5, 0.75, 1.0, 1.5]))
            aggressor = Bool.random(using: &random)
        }
        var flop = deal.flop
        flop.shuffle(using: &random)
        return PracticeScenario(
            id: id, holeCards: deal.hole, flop: flop, betting: betting,
            isPreflopAggressor: aggressor, topic: topic
        )
    }

    private mutating func topPairDeal() throws -> Deal {
        let hole = randomHoleCards(distinctRanks: true)
        let pairRank = hole.map(\.rank).max() ?? .king
        var low = Self.lowRanks
        low.shuffle(using: &random)
        return Deal(hole: hole, flop: try board([pairRank] + low.prefix(2), excluding: hole))
    }

    /// Sets, two pair, broadway-region straights and made flushes vary the value lesson.
    private mutating func valueDeal(kind: Int) throws -> Deal {
        switch kind {
        case 0:
            let rank = pick(Self.faceRanks)
            let hole = try board([rank, rank], excluding: [])
            var low = Self.lowRanks
            low.shuffle(using: &random)
            return Deal(hole: hole, flop: try board([rank] + low.prefix(2), excluding: hole))
        case 1:
            let hole = randomHoleCards(distinctRanks: true)
            return Deal(hole: hole, flop: try board(hole.map(\.rank) + [pick(Self.lowRanks)], excluding: hole))
        case 2:
            let ranks = pick([[Rank.king, .queen], [.jack, .queen], [.jack, .king]])
            let hole = try board(ranks, excluding: [])
            let missingFace = Self.faceRanks.first { !ranks.contains($0) } ?? .jack
            return Deal(hole: hole, flop: try board([missingFace, .ten, .nine], excluding: hole))
        default:
            let hole = randomHoleCards(suited: true)
            var remaining = try Deck.remaining(excluding: hole).filter { $0.suit == hole[0].suit }
            remaining.shuffle(using: &random)
            return Deal(hole: hole, flop: Array(remaining.prefix(3)))
        }
    }

    /// Flush, open-ended and gutshot draws get both cheap and expensive prices.
    private mutating func drawDeal(kind: Int, constructive: Bool) throws -> Deal {
        if kind == 0 {
            let hole = randomHoleCards(suited: true)
            let suit = hole[0].suit
            let offSuit = pick(Suit.allCases.filter { $0 != suit })
            var ranks = Self.lowRanks + [.ace]
            ranks.shuffle(using: &random)
            let selected: [Rank] = constructive ? [.two, .four, .seven] : Array(ranks.prefix(3))
            return Deal(hole: hole, flop: try board(selected, excluding: hole, suits: [suit, suit, offSuit]))
        }
        let hole = randomHoleCards(distinctRanks: true)
        let missingFace = Self.faceRanks.first { !hole.map(\.rank).contains($0) } ?? .jack
        let low = pick(Self.lowRanks.filter { $0 < .nine })
        let ranks: [Rank] = kind == 1 ? [missingFace, .ten, low] : [.ace, missingFace, low]
        return Deal(hole: hole, flop: try board(ranks, excluding: hole, rainbow: true))
    }

    private mutating func deepBetting(fraction: Double, opponentAllIn: Bool = false) throws -> BettingState {
        let prePot = pick([80.0, 100, 150, 200, 300, 400, 600])
        let wager = prePot * fraction
        let displayedPot = prePot + wager
        let heroInitial = displayedPot * pick([2.0, 4, 6])
        let opponentInitial = opponentAllIn ? wager : displayedPot * pick([2.0, 4, 6])
        return try Self.betting(
            preBetPot: prePot, wagerFraction: fraction,
            heroInitialStack: heroInitial, opponentInitialStack: opponentInitial
        )
    }

    private mutating func shortStackBetting(mode: Int) throws -> BettingState {
        let prePot = pick([80.0, 100, 150, 200, 300, 400, 600])
        let fraction: Double
        let hero: Double
        let opponent: Double
        switch mode {
        case 0:
            fraction = 0
            hero = prePot * pick([0.5, 0.75])
            opponent = hero + prePot
        case 1:
            fraction = pick([0.5, 0.75, 1.0])
            hero = prePot * fraction * pick([0.5, 1.0])
            opponent = prePot * (fraction + 2)
        case 2:
            fraction = pick([0.25, 0.33, 0.5])
            hero = prePot * (fraction + pick([0.25, 0.5]))
            opponent = hero + prePot
        default:
            fraction = pick([0.25, 0.33])
            opponent = prePot * (fraction + 0.5)
            hero = opponent + prePot
        }
        return try Self.betting(preBetPot: prePot, wagerFraction: fraction, heroInitialStack: hero, opponentInitialStack: opponent)
    }

    /// Inputs are chips before the villain acts. Its actual wager is deducted
    /// from its stack and added to the pot exactly once, including a short all-in.
    static func betting(
        preBetPot: Double, wagerFraction: Double,
        heroInitialStack: Double, opponentInitialStack: Double
    ) throws -> BettingState {
        guard preBetPot.isFinite, preBetPot > 0,
              wagerFraction.isFinite, wagerFraction >= 0,
              heroInitialStack.isFinite, heroInitialStack > 0,
              opponentInitialStack.isFinite, opponentInitialStack > 0 else {
            throw StrategyInputError.invalidBettingState("Practice pots, stacks and wager fractions must be valid finite amounts.")
        }
        let requestedWager = preBetPot * wagerFraction
        guard requestedWager.isFinite else {
            throw StrategyInputError.invalidBettingState("The requested practice wager is too large.")
        }
        let wager = min(requestedWager, opponentInitialStack)
        guard wager == 0 || wager >= 10 || wager == opponentInitialStack else {
            throw StrategyInputError.invalidBettingState("An opening wager below the big blind must be an opponent all-in.")
        }
        let betting = BettingState(
            pot: preBetPot + wager, amountToCall: wager, heroStack: heroInitialStack,
            opponentStack: opponentInitialStack - wager, bigBlind: 10,
            minimumRaiseIncrement: max(10, wager)
        )
        try betting.validate()
        return betting
    }

    private mutating func randomHoleCards(distinctRanks: Bool = false, suited: Bool = false) -> [Card] {
        let candidates = Deck.allCards.filter { Self.faceRanks.contains($0.rank) }
        let first = pick(candidates)
        let second = pick(candidates.filter {
            $0 != first && (!distinctRanks || $0.rank != first.rank) && (!suited || $0.suit == first.suit)
        })
        return [first, second]
    }

    private mutating func board(
        _ ranks: [Rank], excluding known: [Card], suits: [Suit]? = nil, rainbow: Bool = false
    ) throws -> [Card] {
        var result: [Card] = []
        for (index, rank) in ranks.enumerated() {
            let available = try Deck.remaining(excluding: known + result).filter {
                $0.rank == rank && (suits == nil || $0.suit == suits?[index]) &&
                    (!rainbow || !result.map(\.suit).contains($0.suit))
            }
            guard !available.isEmpty else { throw PracticeGenerationError.unavailableCard }
            result.append(pick(available))
        }
        return result
    }

    private mutating func pick<T>(_ values: [T]) -> T {
        values[Int.random(in: values.indices, using: &random)]
    }

    private struct Deal { let hole: [Card]; let flop: [Card] }
}

private enum PracticeGenerationError: Error {
    case unavailableCard, unconfirmedTopic, emptyCoverage
}

/// Small deterministic RNG; system entropy supplies the default session seed.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
