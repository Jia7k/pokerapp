public enum Position: String, CaseIterable, Hashable, Sendable {
    case underTheGun, hijack, cutoff, button, smallBlind, bigBlind

    public var name: String {
        switch self {
        case .underTheGun: "UTG"
        case .hijack: "HJ"
        case .cutoff: "CO"
        case .button: "BTN"
        case .smallBlind: "SB"
        case .bigBlind: "BB"
        }
    }
}

public enum StackDepth: Int, CaseIterable, Hashable, Sendable {
    case bb20 = 20, bb40 = 40, bb100 = 100

    public static func nearest(to bigBlinds: Double) throws -> StackDepth {
        guard bigBlinds.isFinite, bigBlinds > 0 else {
            throw PokerInputError.invalidChipAmount
        }
        if bigBlinds <= Double(bb20.rawValue) { return .bb20 }
        if bigBlinds >= Double(bb100.rawValue) { return .bb100 }
        return allCases.min {
            let leftDistance = abs(Double($0.rawValue) - bigBlinds)
            let rightDistance = abs(Double($1.rawValue) - bigBlinds)
            if leftDistance == rightDistance { return $0.rawValue < $1.rawValue }
            return leftDistance < rightDistance
        }!
    }
}

public enum PreflopSituation: String, CaseIterable, Hashable, Sendable {
    case unopened, facingOpenRaise
}

public struct StartingHand: Hashable, Sendable {
    private let highRank: Rank
    private let lowRank: Rank
    private let isSuited: Bool

    public init(holeCards: [Card]) throws {
        guard holeCards.count == 2 else {
            throw PokerInputError.invalidCardCount(
                actual: holeCards.count,
                expected: "exactly 2 hole cards"
            )
        }
        guard holeCards[0] != holeCards[1] else {
            throw PokerInputError.duplicateCard(holeCards[0])
        }

        highRank = max(holeCards[0].rank, holeCards[1].rank)
        lowRank = min(holeCards[0].rank, holeCards[1].rank)
        isSuited = highRank == lowRank ? false : holeCards[0].suit == holeCards[1].suit
    }

    private init(highRank: Rank, lowRank: Rank, isSuited: Bool) {
        self.highRank = highRank
        self.lowRank = lowRank
        self.isSuited = highRank == lowRank ? false : isSuited
    }

    public var notation: String {
        let ranks = Self.notationSymbol(highRank) + Self.notationSymbol(lowRank)
        guard highRank != lowRank else { return ranks }
        return ranks + (isSuited ? "s" : "o")
    }

    public static let all: [StartingHand] = {
        let ranks = Array(Rank.allCases.reversed())
        var hands: [StartingHand] = []
        hands.reserveCapacity(169)
        for (highIndex, highRank) in ranks.enumerated() {
            hands.append(StartingHand(highRank: highRank, lowRank: highRank, isSuited: false))
            for lowRank in ranks.dropFirst(highIndex + 1) {
                hands.append(StartingHand(highRank: highRank, lowRank: lowRank, isSuited: true))
                hands.append(StartingHand(highRank: highRank, lowRank: lowRank, isSuited: false))
            }
        }
        return hands
    }()

    private static func notationSymbol(_ rank: Rank) -> String {
        rank == .ten ? "T" : rank.symbol
    }
}

public enum PreflopChartAction: Equatable, Sendable {
    case fold, check, call
    case raise(bigBlinds: Double)
    case threeBet(multiplier: Double)
}

public struct PreflopKey: Hashable, Sendable {
    public let position: Position
    public let hand: StartingHand
    public let depth: StackDepth
    public let situation: PreflopSituation

    public init(
        position: Position,
        hand: StartingHand,
        depth: StackDepth,
        situation: PreflopSituation
    ) {
        self.position = position
        self.hand = hand
        self.depth = depth
        self.situation = situation
    }
}

/// GTO-inspired simplified six-seat presets for a single heads-up decision.
/// These are not solver charts. Opener position/range and multiway, limped, and
/// re-raised pots are deliberately outside the model.
public enum PreflopStrategy {
    public static let chart: [PreflopKey: PreflopChartAction] = {
        let handsByNotation = Dictionary(
            uniqueKeysWithValues: StartingHand.all.map { ($0.notation, $0) }
        )
        var result: [PreflopKey: PreflopChartAction] = [:]
        result.reserveCapacity(6_084)

        for position in Position.allCases {
            for hand in StartingHand.all {
                for depth in StackDepth.allCases {
                    for situation in PreflopSituation.allCases {
                        let defaultAction: PreflopChartAction =
                            position == .bigBlind && situation == .unopened ? .check : .fold
                        result[PreflopKey(
                            position: position,
                            hand: hand,
                            depth: depth,
                            situation: situation
                        )] = defaultAction
                    }
                }
            }
        }

        for depth in StackDepth.allCases {
            for position in Position.allCases {
                for notation in notations(in: openingPresets[depth]![position]!) {
                    result[PreflopKey(
                        position: position,
                        hand: requiredHand(notation, in: handsByNotation),
                        depth: depth,
                        situation: .unopened
                    )] = .raise(bigBlinds: 2.5)
                }

                for notation in notations(in: callingPresets[depth]![position]!) {
                    result[PreflopKey(
                        position: position,
                        hand: requiredHand(notation, in: handsByNotation),
                        depth: depth,
                        situation: .facingOpenRaise
                    )] = .call
                }

                let multiplier = position == .smallBlind || position == .bigBlind ? 4.0 : 3.0
                for notation in notations(in: threeBetPresets[depth]![position]!) {
                    result[PreflopKey(
                        position: position,
                        hand: requiredHand(notation, in: handsByNotation),
                        depth: depth,
                        situation: .facingOpenRaise
                    )] = .threeBet(multiplier: multiplier)
                }
            }
        }

        precondition(result.count == 6_084, "Preflop chart must cover every key")
        return result
    }()

    public static func action(
        position: Position,
        hand: StartingHand,
        depth: StackDepth,
        situation: PreflopSituation
    ) -> PreflopChartAction {
        chart[PreflopKey(
            position: position,
            hand: hand,
            depth: depth,
            situation: situation
        )]!
    }

    private static func notations(in list: String) -> [Substring] {
        list.split(whereSeparator: \Character.isWhitespace)
    }

    private static func requiredHand(
        _ notation: Substring,
        in handsByNotation: [String: StartingHand]
    ) -> StartingHand {
        guard let hand = handsByNotation[String(notation)] else {
            preconditionFailure("Unknown starting-hand notation: \(notation)")
        }
        return hand
    }

    private static let openingPresets: [StackDepth: [Position: String]] = [
        .bb20: [
            .underTheGun: "77 88 99 TT JJ QQ KK AA AJs AQs AKs AQo AKo KQs",
            .hijack: "66 77 88 99 TT JJ QQ KK AA ATs AJs AQs AKs AJo AQo AKo KJs KQs KQo QJs",
            .cutoff: "66 77 88 99 TT JJ QQ KK AA A8s A9s ATs AJs AQs AKs ATo AJo AQo AKo KTs KJs KQs KJo KQo QTs QJs QJo JTs T9s 98s",
            .button: "44 55 66 77 88 99 TT JJ QQ KK AA A2s A3s A4s A5s A6s A7s A8s A9s ATs AJs AQs AKs A8o A9o ATo AJo AQo AKo K8s K9s KTs KJs KQs KTo KJo KQo Q9s QTs QJs QJo J9s JTs T9s 98s 87s 76s",
            .smallBlind: "55 66 77 88 99 TT JJ QQ KK AA A2s A3s A4s A5s A6s A7s A8s A9s ATs AJs AQs AKs A9o ATo AJo AQo AKo K9s KTs KJs KQs KTo KJo KQo QTs QJs QJo JTs T9s 98s",
            .bigBlind: ""
        ],
        .bb40: [
            .underTheGun: "66 77 88 99 TT JJ QQ KK AA ATs AJs AQs AKs AQo AKo KJs KQs KQo QJs JTs",
            .hijack: "55 66 77 88 99 TT JJ QQ KK AA A9s ATs AJs AQs AKs AJo AQo AKo KTs KJs KQs KQo QTs QJs JTs T9s",
            .cutoff: "44 55 66 77 88 99 TT JJ QQ KK AA A2s A3s A4s A5s A8s A9s ATs AJs AQs AKs ATo AJo AQo AKo K9s KTs KJs KQs KJo KQo Q9s QTs QJs QJo J9s JTs T9s 98s 87s",
            .button: "22 33 44 55 66 77 88 99 TT JJ QQ KK AA A2s A3s A4s A5s A6s A7s A8s A9s ATs AJs AQs AKs A8o A9o ATo AJo AQo AKo K7s K8s K9s KTs KJs KQs KTo KJo KQo Q8s Q9s QTs QJs QTo QJo J8s J9s JTs JTo T8s T9s 97s 98s 86s 87s 76s 65s 54s",
            .smallBlind: "44 55 66 77 88 99 TT JJ QQ KK AA A2s A3s A4s A5s A6s A7s A8s A9s ATs AJs AQs AKs A9o ATo AJo AQo AKo K8s K9s KTs KJs KQs KTo KJo KQo Q9s QTs QJs QJo J9s JTs T9s 98s 87s 76s",
            .bigBlind: ""
        ],
        .bb100: [
            .underTheGun: "55 66 77 88 99 TT JJ QQ KK AA ATs AJs AQs AKs AQo AKo KJs KQs KQo QJs JTs 98s",
            .hijack: "44 55 66 77 88 99 TT JJ QQ KK AA A5s A9s ATs AJs AQs AKs AJo AQo AKo KTs KJs KQs KQo QTs QJs JTs T9s 98s 87s",
            .cutoff: "33 44 55 66 77 88 99 TT JJ QQ KK AA A2s A3s A4s A5s A7s A8s A9s ATs AJs AQs AKs ATo AJo AQo AKo K9s KTs KJs KQs KJo KQo Q9s QTs QJs QJo J9s JTs T9s 98s 87s 76s 65s",
            .button: "22 33 44 55 66 77 88 99 TT JJ QQ KK AA A2s A3s A4s A5s A6s A7s A8s A9s ATs AJs AQs AKs A7o A8o A9o ATo AJo AQo AKo K6s K7s K8s K9s KTs KJs KQs K9o KTo KJo KQo Q7s Q8s Q9s QTs QJs QTo QJo J8s J9s JTs JTo T8s T9s 97s 98s 86s 87s 75s 76s 65s 54s",
            .smallBlind: "33 44 55 66 77 88 99 TT JJ QQ KK AA A2s A3s A4s A5s A6s A7s A8s A9s ATs AJs AQs AKs A8o A9o ATo AJo AQo AKo K7s K8s K9s KTs KJs KQs KTo KJo KQo Q8s Q9s QTs QJs QJo J8s J9s JTs T8s T9s 98s 87s 76s 65s",
            .bigBlind: ""
        ]
    ]

    private static let callingPresets: [StackDepth: [Position: String]] = [
        .bb20: [
            .underTheGun: "77 88 99 TT AQs KQs",
            .hijack: "66 77 88 99 AJs KQs QJs",
            .cutoff: "55 66 77 88 ATs KQs KJs QJs JTs T9s",
            .button: "44 55 66 77 A9s KTs KJs KQs KQo QJs JTs T9s 98s",
            .smallBlind: "66 77 88 AJs KQs QJs",
            .bigBlind: "22 33 44 55 66 77 88 A2s A3s A4s A5s A8s A9s K9s KTs KJs KQs KQo QTs QJs JTs T9s 98s 87s"
        ],
        .bb40: [
            .underTheGun: "77 88 99 TT JJ AJs AQs KQs",
            .hijack: "66 77 88 99 TT AJs AQs KQs QJs",
            .cutoff: "55 66 77 88 99 ATs AJs AQo KJs KQs QJs JTs T9s",
            .button: "22 33 44 55 66 77 88 A9s ATs AJs AJo AQo KTs KJs KQs KQo QTs QJs JTs T9s 98s 87s",
            .smallBlind: "66 77 88 99 ATs AJs AQo KJs KQs QJs JTs",
            .bigBlind: "22 33 44 55 66 77 88 99 A2s A3s A4s A8s A9s ATs AJs AJo AQo K8s K9s KTs KJs KQs KJo KQo Q9s QTs QJs QJo J9s JTs T9s 98s 87s 76s"
        ],
        .bb100: [
            .underTheGun: "22 33 44 55 66 77 88 99 TT JJ AJs AQs KQs QJs JTs",
            .hijack: "22 33 44 55 66 77 88 99 TT AJs AQs AQo KJs KQs QJs JTs T9s",
            .cutoff: "22 33 44 55 66 77 88 99 TT ATs AJs AQo KTs KJs KQs KQo QTs QJs JTs T9s 98s 87s",
            .button: "22 33 44 55 66 77 88 99 ATs AJs AJo AQo KTs KJs KQs KJo KQo QTs QJs QJo JTs JTo T9s 98s 87s 76s 65s",
            .smallBlind: "22 33 44 55 66 77 88 99 TT ATs AJs AQo KTs KJs KQs KQo QJs JTs T9s 98s",
            .bigBlind: "22 33 44 55 66 77 88 99 TT A2s A3s A4s A6s A7s A8s A9s ATs AJs AJo AQo K7s K8s K9s KTs KJs KQs KJo KQo Q8s Q9s QTs QJs QJo J8s J9s JTs JTo T8s T9s 97s 98s 86s 87s 75s 76s 65s 54s"
        ]
    ]

    private static let threeBetPresets: [StackDepth: [Position: String]] = [
        .bb20: [
            .underTheGun: "JJ QQ KK AA AKs AKo",
            .hijack: "TT JJ QQ KK AA AQs AKs AKo",
            .cutoff: "99 TT JJ QQ KK AA AJs AQs AKs AQo AKo",
            .button: "88 99 TT JJ QQ KK AA ATs AJs AQs AKs AJo AQo AKo",
            .smallBlind: "99 TT JJ QQ KK AA AJs AQs AKs AQo AKo",
            .bigBlind: "99 TT JJ QQ KK AA AJs AQs AKs AQo AKo"
        ],
        .bb40: [
            .underTheGun: "QQ KK AA AKs AKo",
            .hijack: "JJ QQ KK AA AKs AKo",
            .cutoff: "TT JJ QQ KK AA A5s AQs AKs AKo",
            .button: "99 TT JJ QQ KK AA A5s AQs AKs AKo",
            .smallBlind: "TT JJ QQ KK AA A5s AQs AKs AKo",
            .bigBlind: "JJ QQ KK AA A5s AQs AKs AKo"
        ],
        .bb100: [
            .underTheGun: "QQ KK AA AKs AKo",
            .hijack: "QQ KK AA A5s AKs AKo",
            .cutoff: "JJ QQ KK AA A4s A5s AQs AKs AKo",
            .button: "TT JJ QQ KK AA A4s A5s AQs AKs AKo",
            .smallBlind: "JJ QQ KK AA A4s A5s AQs AKs AKo",
            .bigBlind: "QQ KK AA A4s A5s AQs AKs AKo"
        ]
    ]
}
