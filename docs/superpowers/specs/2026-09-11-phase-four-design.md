# Phase 4 — GTO Practice Tool

Build a separate offline Practice tab beside the live Table dashboard. This implements the user's requested face-card flop quiz with the existing Card, Deck and PostflopHeuristicEngine types. It grades agreement with Riverline's simplified rules, not solver-derived GTO.

## Scenarios and grading

Updated per the user's unlimited-drills request: generate each flop on demand by sampling two physical J/Q/K cards without replacement and shuffling the remaining Deck for three community cards. Randomize valid pots, stacks, preflop initiative and betting context, and validate the engine's recommendation before presenting the drill. Bound rejection attempts and memory, with a checked-to fallback on a random deal. Use system randomness normally and a reproducible seed for tests. The original ten-input catalog remains only for explicit curated injection and fixtures, including K♠ Q♠ on A♥ 8♦ 2♣.

Keep the requested Bet, Check and Fold labels unless the user elects contextual labels in the pending optional clarification. Only load scenarios whose engine answer is representable: checked-to bets and opening all-ins map to Bet, free checks to Check, and folds facing a bet to Fold. Reject Call, Raise, all-in calls/raises and no-action answers instead of silently mapping them to a wrong choice. The amount to call is explicit in any facing-bet drill. Incorrect illegal choices receive explanatory feedback; no actual betting is executed.

The bank includes dry continuation bets, wet-board checks, a made straight/flush/set, short-SPR top pair, and expensive draws/top-pair folds. Store inputs only; the existing engine produces every answer. Sizing is explained after selection and is not scored.

## State

PracticeViewModel is a main-actor observable object in PokerCore. It owns the active scenario, private engine analysis, optional immutable feedback, running correct/attempt counts, and an error state. Submission is accepted exactly once per scenario. Next Scenario clears feedback and advances only after grading, while retaining score. Empty, malformed or unsupported catalogs produce a readable unavailable state and never stale advice or extra points. Progress lasts for the current app session and survives switching tabs.

Practice state is independent of PokerSession: drills never replace live cards, table values or bankroll.

## Interface

PracticeView in PokerUI uses existing casino colors, formatting and playing-card faces. Before answering, show hole cards, flop, pot, effective stack, amount to call and preflop-aggressor context. Hide engine strength, texture, SPR and recommendation until grading. Below the cards show three large action buttons. Replace them with CORRECT/INCORRECT, the selected and engine actions, explanation, texture, SPR and a Next Scenario button. Always show Correct: X/Y.

Updated per the user's layout request: Practice must fit on one screen without scrolling. Scale cards, typography and spacing to the available geometry; use stacked panels in portrait and two columns in landscape. Bound text growth to preserve the fixed layout. Keep tap targets at least 44 points and complete card/score/feedback accessibility labels, and respect Reduce Motion. No network, new external dependency, random answer table or new financial action is introduced.

## Verification

Test real engine-backed answers, one-shot grading, incorrect answers, unlimited progression, seed replay, randomized input diversity, all-in bet/call distinctions, invalid cards/stacks and empty/unsupported catalogs. Retain cyclic progression only for injected curated arrays. Add simulator journeys for tab entry, correct and incorrect answers, score retention, Next reset, live-table isolation and largest Dynamic Type. Require fully visible content without scrolling across twelve generated drills and landscape. Per the latest user instruction, build and verify native behavior on iPhone 16 Pro only.
