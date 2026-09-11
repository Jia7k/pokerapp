# Phase 4 — GTO Practice Tool

Build a separate offline Practice tab beside the live Table dashboard. This implements the user's requested face-card flop quiz with the existing Card, Deck and PostflopHeuristicEngine types. It grades agreement with Riverline's simplified rules, not solver-derived GTO.

## Scenarios and grading

Use a curated bank of ten flop inputs, cycling in a fixed order for repeatable drills. The first is K♠ Q♠ on A♥ 8♦ 2♣, pot 100, effective stack 400, no call, hero the preflop aggressor. Every built-in hand contains two J/Q/K cards and three unique community cards. Reuse Deck's exclusion validation rather than maintain a second deck implementation.

Keep the requested Bet, Check and Fold labels unless the user elects contextual labels in the pending optional clarification. Only load scenarios whose engine answer is representable: checked-to bets and opening all-ins map to Bet, free checks to Check, and folds facing a bet to Fold. Reject Call, Raise, all-in calls/raises and no-action answers instead of silently mapping them to a wrong choice. The amount to call is explicit in any facing-bet drill. Incorrect illegal choices receive explanatory feedback; no actual betting is executed.

The bank includes dry continuation bets, wet-board checks, a made straight/flush/set, short-SPR top pair, and expensive draws/top-pair folds. Store inputs only; the existing engine produces every answer. Sizing is explained after selection and is not scored.

## State

PracticeViewModel is a main-actor observable object in PokerCore. It owns the active scenario, private engine analysis, optional immutable feedback, running correct/attempt counts, and an error state. Submission is accepted exactly once per scenario. Next Scenario clears feedback and advances only after grading, while retaining score. Empty, malformed or unsupported catalogs produce a readable unavailable state and never stale advice or extra points. Progress lasts for the current app session and survives switching tabs.

Practice state is independent of PokerSession: drills never replace live cards, table values or bankroll.

## Interface

PracticeView in PokerUI uses existing casino colors, formatting and playing-card faces. Before answering, show hole cards, flop, pot, effective stack, amount to call and preflop-aggressor context. Hide engine strength, texture, SPR and recommendation until grading. Below the cards show three large action buttons. Replace them with CORRECT/INCORRECT, the selected and engine actions, explanation, texture, SPR and a Next Scenario button. Always show Correct: X/Y.

Updated per the user's layout request: Practice must fit on one screen without scrolling. Scale cards, typography and spacing to the available geometry; use stacked panels in portrait and two columns in landscape. Bound text growth to preserve the fixed layout. Keep tap targets at least 44 points and complete card/score/feedback accessibility labels, and respect Reduce Motion. No network, new external dependency, random answer table or new financial action is introduced.

## Verification

Test real engine-backed answers, one-shot grading, incorrect answers, cyclic progression, all-in bet/call distinctions, invalid cards/stacks and empty/unsupported catalogs. Run the full existing engine suite for engine changes. Add simulator journeys for tab entry, Bet correctness, a wrong answer, score retention, Next reset, live-table isolation and largest Dynamic Type. Require fully visible content without scrolling for all ten drills and landscape. Build the native app and inspect screenshots on iPhone 17 Pro and compact iPhone SE.
