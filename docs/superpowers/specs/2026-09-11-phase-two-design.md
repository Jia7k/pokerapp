# Phase 2: Local strategy and observable state

The user approved Phase 2 after the Phase 1 handoff. Implement strategy and a SwiftUI-ready view model now, stopping before views. Retain Swift 6, iOS 17+, macOS 14+, zero external dependencies, and entirely offline execution.

## Preflop

Use six positions (UTG, HJ, CO, BTN, SB, BB), all 169 canonical starting hands, depth buckets 20/40/100 BB, and unopened/facing-open-raise situations. Each dictionary key has position, starting hand, depth and situation. Hardcoded explicit range lists expand into a complete lookup, with fold as a deliberate default and check for an unopened big blind. These are simplified GTO-inspired charts, not solver-derived GTO or multiway strategy. Select the nearest depth, resolving ties toward the shallower bucket. Display the bucket/approximation and scope in recommendations. Button A5s at 40 BB opens to 2.5 BB. Facing-open charts provide call and 3-bet actions, with 3x in-position / 4x blind sizing. Unsupported action sequences (limpers, 3/4-bets, multiway) are outside these presets.

## Betting conventions

Model one opponent. `heroStack` and `opponentStack` are chips remaining behind, after earlier contributions. `amountToCall` is the outstanding difference, and `pot` already includes that outstanding bet. Effective additional commitment is `min(heroStack, opponentStack + amountToCall)`. A short hero call excludes the uncallable excess of the opponent's bet from the contestable pot. `heroStreetContribution` and `minimumRaiseIncrement` allow legal total raise sizing. Bankroll is a separate session balance; recommendations never debit it or execute actions. Validate finite nonnegative amounts, positive blind/minimum raise increment, and pot at least outstanding call plus hero contribution. No side pots or multiway action.

## Postflop

Analyze 3–5 community cards, including suit concentration, pairing and three ranks inside any five-rank straight window (ace-low included, no wraparound). Primary texture: dry/rainbow, wet/connected, monotone. Assess hero-owned top pair/overpair/made strength; a pair, trips or quads supplied solely by the board must not trigger value aggression.

Decision ordering: no action when already all-in; check when no further matched betting is possible; SPR < 1 with hero-owned top pair or better -> all-in (or ordinary call when the opponent is already all-in and the hero has extra chips); a facing bet is handled before any c-bet rule; strong made hands may call independently of draw-outs count; weak drawing hands compare the appropriate draw horizon with pot odds; checked-to dry flop + preflop aggressor -> 33% c-bet; otherwise use modest value betting for strong made hands or check. A flop call that closes betting uses Rule of 4; ordinary flop calls and all turn calls use exact next-card completion probability. The display still shows Rule of 4 on the flop and Rule of 2 on the turn. This remains a heuristic comparison of potential completions, not actual opponent equity. River draws are unavailable. Bet amounts are bounded by stack coverage and the minimum bet.

## MVVM

`@MainActor @Observable PokerViewModel` exposes editable position, situation, bankroll, aggressor flag and betting state. Seven optional card slots are updated through validated setters. Duplicate choices and out-of-order later streets are rejected atomically. Partial hole/flop selections show an incomplete state and clear stale recommendations. Clearing a flop clears turn/river; clearing turn clears river. Each valid edit recomputes one immutable analysis snapshot synchronously; computations are small and deterministic. Preserve bankroll/stacks when resetting cards for a new hand.

## Verification

Test all 169 canonical hands and dictionary coverage, chart examples and depth boundaries; texture and board-owned hand traps; legal capped actions; draw horizon and 25% vs 16% fold example; zero-outs made hands; short calls and uncallable pot amounts; view-model observation, recomputation, incomplete/error transitions, card validation and new-hand reset. Run the full Swift suite, the existing exhaustive evaluator audit, and Swift 6 iOS Simulator compilation. Independently review strategy and integration before completion.

## Review refinements

Guaranteed river board splits are proven locally against legal remaining opponent holdings and call/check rather than folding for zero draw outs. Hero-owned weak pairs are distinguished from board-supplied categories in explanations. Coverage-limited checks explain the actual action. Betting arithmetic preserves short matched calls and avoids intermediate overflow in representable all-ins and chart depth/sizing.
