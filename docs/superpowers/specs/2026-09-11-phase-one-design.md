# Phase 1: Offline poker foundation

The user's three-phase specification authorizes implementation of Phase 1 now. Deliver a dependency-free Swift 6 package, supporting iOS 17+ and macOS 14+ for local testing. Strategy, MVVM, and SwiftUI screens belong to subsequent phases.

## Design

- `Card.swift`: immutable, hashable, Codable, Sendable rank/suit/card values, with stable card identity and readable Unicode display.
- `Deck.swift`: a unique 52-card deck, exclusion of known cards with duplicate validation, optional shuffle and safe drawing.
- `HandEvaluator.swift`: validate 5–7 unique cards, enumerate all five-card subsets, rank each, and return the highest category and complete lexicographic tiebreak vector. Ace-low straights rank as five-high; suits never break ties. Brute-force five-card subsets are transparent and inexpensive at this scale (21 subsets for seven cards), without Cactus Kev lookup tables.
- `OutsCalculator.swift`: accept two hole cards, 3–5 community cards and optional known dead cards. Enumerate remaining next cards; report each unique card that upgrades the current category into a straight, flush, full house, quads, or straight flush. Exclude river cards that leave the hero playing the board. River reports no further outs. Same-category improvements, pair/trips improvements, and backdoor two-card draws are outside this explicitly narrow completion metric.
- `PokerMath.swift`: pot odds as call / (pot before call + call), and Rule of 4 on the flop / Rule of 2 on the turn, capped at 100%. Report probabilities as 0...1. No draw estimate exists preflop or on the river.

## Accuracy boundary

Out-card enumeration is exact under the completion definition. With unknown opponent cards/ranges, neither these outs nor the Rule of 2/4 establishes winning equity. Board-only changes and overlapping straight/flush outs must not inflate the count. Consumers must label the result as potential made-hand outs and approximate draw probability; zero draw outs does not mean zero chance to win.

## Verification

Use real XCTest fixtures for all categories, kickers, wheels, double trips, three pairs, board play, duplicate rejection, draw overlaps, full-house draws, dead cards, stage transitions, and invalid math inputs. An opt-in exhaustive release test checks all 2,598,960 five-card combinations against independently known category totals and 7,462 distinct values. Compile the library for an iOS simulator target.
