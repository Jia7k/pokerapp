# Phase 4 — GTO Practice Tool

Build a separate offline Practice tab beside the live Table dashboard. This implements the user's requested face-card flop quiz with the existing Card, Deck and PostflopHeuristicEngine types. It grades agreement with Riverline's simplified rules, not solver-derived GTO.

## Scenarios and grading

Generate fresh drills on demand, each with two physical J/Q/K hole cards and three unique flop cards from Deck. Following the accepted adaptive-practice improvement, each shuffled round contains all six topics: continuation bets, checking, short stacks, value betting, draw pricing and facing bets. Add up to three weighted reviews of topics with mistakes. Smoothed error weights fade as accuracy improves. Construct cards and betting context for the selected concept, and require the shared engine to confirm that concept. Bound retries to eight and then use a randomized constructive fallback for the same topic. Keep only the current drill and a queue of at most nine topics. Use system randomness normally; tests replay a seed, initial learning record and answer sequence. The original ten-input catalog remains only for explicit curated injection and fixtures, including K♠ Q♠ on A♥ 8♦ 2♣.

Use the accepted contextual actions: Check/Bet when checked to and Fold/Call/Raise facing a wager, omitting actions that stacks or minimum-raise rules prevent. Opening all-ins map to Bet; all-ins at the call cost map to Call; all-ins above the call cost map to Raise. Ignore unavailable or stale submissions without scoring. The amount to call and all-in context are explicit; no actual betting is executed.

Generate the pot before the opponent's wager, calculate that wager as a fraction of the pot, deduct it from the opponent's initial stack and add it to the displayed pot exactly once. Include ordinary bets, deliberate overbets and all-ins. The existing engine produces every answer. After selection, explain actual SPR, sizing and, where decisive, draw-completion probability against pot odds. Distinguish next-card completion from the Rule-of-4 estimate for a closing all-in call. Completion probability is not win equity. Sizing is explained but is not scored.

## State

PracticeViewModel is a main-actor observable object in PokerCore. It owns the active scenario, cached engine analysis, legal choices, immutable feedback, running score, per-topic learning record and error state. Submission is accepted exactly once per scenario. Next Scenario clears feedback and advances only after grading. Empty, malformed or unsupported catalogs produce a readable unavailable state and never stale advice or extra points. The session score survives tab changes and resets on relaunch. Topic accuracy persists in a separate versioned local defaults key. Validate restored counts, bound accumulated counters and recover safely from corrupt or incompatible data.

Practice state is independent of PokerSession: drills never replace live cards, table values or bankroll.

## Interface

PracticeView in PokerUI uses existing casino colors, formatting and playing-card faces. Before answering, show hole cards, flop, pot, effective stack, amount to call and preflop-aggressor context. Hide the answer, topic, strength, texture and SPR until grading. Show only the available action buttons. Replace them with CORRECT/INCORRECT, selected and recommended actions, numerical explanation, saved topic accuracy, texture, SPR and Next Scenario. Always show Correct: X/Y. Label the community cards FLOP with no drill counter or total.

Updated per the user's layout request: Practice must fit on one screen without scrolling. Scale cards, typography and spacing to the available geometry; use stacked panels in portrait and two columns in landscape. Bound text growth to preserve the fixed layout. Keep tap targets at least 44 points and complete card/score/feedback accessibility labels, and respect Reduce Motion. No network, new external dependency, random answer table or new financial action is introduced.

## Verification

Test engine-backed grading for all five actions, all-in Bet/Call/Raise distinctions, unavailable actions, guarded scoring, numerical feedback, both draw horizons, valid wager/stack math, all six topics, adaptive recovery, bounded fallback, seeded replay and generated card diversity. Retain cyclic progression only for injected curated arrays. Verify persistence round trips, malformed data and separation from the live-session key. Native journeys cover correct/incorrect grading, ordinary and all-in calls, all-in raises, twelve generated drills, full feedback at largest Dynamic Type and in landscape, plain FLOP, live-card isolation and persistence across relaunch. Build and verify native behavior on iPhone 16 Pro only.
