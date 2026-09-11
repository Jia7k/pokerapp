import Foundation

/// A compact explanation of the same numbers and rule that produced the answer.
enum PracticeFeedbackBuilder {
    static func explanation(for prepared: PreparedPracticeScenario) -> String {
        let scenario = prepared.scenario
        let analysis = prepared.analysis
        let betting = scenario.betting
        let hand = handDescription(analysis.madeHand, scenario: scenario)
        let action = actionDescription(analysis.recommendation.action, betting: betting)
        let spr = stackRatioDescription(betting)

        switch analysis.recommendation.reason {
        case .shortStackValue:
            return "\(hand). \(spr) (< 1). \(action) under the short-stack rule."
        case .dryBoardContinuationBet:
            return "Dry rainbow flop; you raised preflop. \(action) using the small continuation-bet rule."
        case .madeHandValue:
            if betting.amountToCall == 0 {
                return "\(hand). \(spr). \(action) for value."
            }
            let limit = analysis.madeHand.hasTopPairOrBetter && !analysis.madeHand.isStrongMadeHand
                ? "Within this rule's 33.3% top-pair limit." : "Continue under the made-hand rule."
            return "\(hand). \(potOdds(betting)). \(limit) \(action)."
        case .drawPriceAcceptable, .drawTooExpensive:
            if analysis.madeHand.hasTopPairOrBetter {
                return "\(hand). \(potOdds(betting)). Above this rule's 33.3% top-pair limit: \(action.lowercased())."
            }
            let completion: String
            if betting.closesBettingByCalling {
                completion = "Rule of 4: \(analysis.outs.count) × 4 ≈ \(percent(analysis.approximateDrawProbability ?? 0)) completion by river"
            } else {
                completion = "\(analysis.outs.count)/\(analysis.outs.unseenCardCount) = \(percent(analysis.decisionDrawProbability ?? 0)) next-card completion"
            }
            return "\(completion). \(potOdds(betting)). \(action). Completion is not win equity."
        case .boardOnlyHand:
            return "The made-hand category comes from the board. \(spr). \(action)."
        case .checkWithoutValue:
            return "\(hand) on a \(textureDescription(analysis.texture.texture)) flop. \(spr). \(action): this rule needs more made-hand value."
        case .insufficientCoverage:
            return "Opponent covers \(number(betting.opponentStack)) chips, below the \(number(betting.bigBlind)) minimum bet. \(action)."
        default:
            return analysis.recommendation.explanation
        }
    }

    private static func potOdds(_ betting: BettingState) -> String {
        let required = (try? betting.requiredEquity()) ?? 0
        return "Call \(number(betting.callCost))/(\(number(betting.contestablePot)) + \(number(betting.callCost))) = \(percent(required)) required"
    }

    private static func stackRatioDescription(_ betting: BettingState) -> String {
        let ratio = betting.stackToPotRatio ?? 0
        let formatted = number(ratio)
        if ratio != 1, formatted == "1" {
            // Preserve which side of the rule's exact threshold this hand is on.
            // Rounded chips can also create a misleading "100/100 < 1" here.
            return "SPR = \(String(ratio))"
        }
        let relation = Double(formatted) == ratio ? "=" : "≈"
        return "SPR \(number(betting.effectiveStack))/\(number(betting.pot)) \(relation) \(formatted)"
    }

    private static func actionDescription(_ action: PokerAction, betting: BettingState) -> String {
        switch action {
        case .bet(let amount): "Bet \(number(amount)) (\(percent(amount / betting.pot)) pot)"
        case .check: "Check"
        case .fold: "Fold"
        case .call(let amount): "Call \(number(amount))"
        case .raise(let total): "Raise to \(number(total))"
        case .allIn(let amount):
            if betting.amountToCall == 0 {
                "Bet all in \(number(amount))"
            } else if amount <= betting.callCost {
                "Call all in \(number(amount))"
            } else {
                "Raise all in with \(number(amount)) more chips"
            }
        case .noAction: "No action"
        }
    }

    private static func handDescription(_ hand: MadeHandAssessment, scenario: PracticeScenario) -> String {
        switch hand.value.category {
        case .highCard: "High card"
        case .onePair:
            if scenario.holeCards[0].rank == scenario.holeCards[1].rank,
               let highestBoardRank = scenario.flop.map(\.rank).max(),
               scenario.holeCards[0].rank > highestBoardRank {
                "Overpair"
            } else if hand.hasTopPairOrBetter {
                "Top pair"
            } else {
                "One pair"
            }
        case .twoPair: "Two pair"
        case .threeOfAKind: "Three of a kind"
        case .straight: "Straight"
        case .flush: "Flush"
        case .fullHouse: "Full house"
        case .fourOfAKind: "Four of a kind"
        case .straightFlush: "Straight flush"
        }
    }

    private static func textureDescription(_ texture: BoardTexture) -> String {
        switch texture {
        case .dryRainbow: "dry rainbow"
        case .wetConnected: "wet or connected"
        case .monotone: "monotone"
        }
    }

    private static func number(_ value: Double) -> String {
        guard value.isFinite else { return "∞" }
        return value.formatted(.number.locale(Locale(identifier: "en_US_POSIX"))
            .grouping(.never).precision(.fractionLength(0...2)))
    }

    private static func percent(_ value: Double) -> String {
        (value * 100).formatted(.number.locale(Locale(identifier: "en_US_POSIX"))
            .grouping(.never).precision(.fractionLength(0...1))) + "%"
    }
}
