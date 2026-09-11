# Phase 4 — Adaptive GTO Practice

The Practice tab generates unlimited offline face-card flop drills and grades decisions against Riverline's shared postflop heuristics. The latest refinement adds contextual legal actions, accurate wager construction, numerical explanations and persistent adaptive practice.

## Actions and grading

`PreparedPracticeScenario` validates inputs and caches the real engine analysis. When checked to, the view offers Check and Bet. Facing a wager, it offers Fold, Call and, when stacks and minimum-raise rules allow it, Raise. An opening all-in is a Bet; an all-in at the call cost is a Call; an all-in above the call cost is a Raise. If an action is unavailable, it is neither displayed nor accepted for scoring.

`PracticeViewModel` accepts one answer per drill, shows immutable feedback and updates the session score and topic accuracy once. Next Scenario clears the result and generates another drill. Injected fixture catalogs remain supported, including the original K♠ Q♠ example, but are not the default source of practice.

Numerical feedback explains the decisive calculation. A short-stack drill shows effective stack / pot and the resulting SPR. A value or continuation bet shows its chip amount and pot fraction. Draw pricing compares the applicable completion estimate with call cost / (contestable pot + call cost). Ordinary flop calls use next-card completion; closing all-in calls use the approximate Rule of 4 through the river. Completion probability is explicitly distinguished from win equity. This is training against simplified heads-up heuristics, not a GTO solver.

## Unlimited adaptive generation

Each round contains six concepts: continuation bets, checking, short stacks, value betting, draw pricing and facing bets. The generator adds up to three weighted review slots for concepts with mistakes, then shuffles the whole round. Smoothed error weights decline as accuracy improves, while the six base entries maintain broad coverage.

Every drill constructs new cards, suits, pots and stacks for its selected concept. Both hole cards are J, Q or K; all five physical cards are distinct. The shared heuristic engine must confirm the generated concept and legal recommendation. After at most eight candidate attempts, a randomized constructive fallback guarantees the same concept. Generator state is bounded to a seed, ordinal and queue of at most nine topics; no growing history or fixed ten-drill cycle is stored. Finite card combinations can recur during unlimited play.

Pots before betting range from 80 to 600 chips at a 10-chip big blind. Facing-bet fractions include 25%, 33%, 50%, 75%, 100% and deliberate 150% overbets. The actual wager is capped by the opponent's initial stack, subtracted from that stack and added to the pot exactly once. The minimum raise increment uses the actual opening wager, with the big blind as its lower bound. Short-stack constructions also exercise hero all-in calls, all-in raises and covered full raises.

SplitMix64 is seeded from system randomness for normal play. The seed, initial learning progress and answer sequence reproduce a session for tests. Topics are selected using the latest learning record when the bounded queue is refilled.

## Persistence and interface

`PracticeProgressStore` saves a versioned six-topic accuracy record under `riverline.practice-learning.v1`. Restored counts are validated; corrupt or incompatible data starts an empty record. Very large counts are proportionally aged before further recording. The live table uses a different key. UI tests use a separate defaults suite.

The Practice model is owned independently of `PokerSession`. Switching tabs retains the current drill, result and score; relaunching starts a fresh session score while retaining topic accuracy. Practice never replaces live cards or debits the bankroll. After each answer, the result displays the topic and its saved correct/attempt count.

Practice remains a fixed canvas with no scroll view. Portrait stacks the scenario and decision panels; landscape places them side by side. Cards, typography and spacing scale to the available geometry. Buttons retain at least 44-point tap targets, complete explanations remain accessible, and the community-card heading is simply FLOP. Before grading, the interface hides the topic, board classification, SPR and answer.

## Verification

On 2026-09-11, all **159 release unit tests passed**, including the exhaustive audit of all 2,598,960 five-card combinations and 7,462 distinct values. Practice checks cover all five actions, all-in distinctions, guarded scoring, numerical feedback, both draw horizons, wager/stack arithmetic, all six concepts, bounded fallbacks, adaptive weighting, seeded replay and persistence isolation. Independent core, generator and persistence reviews found no actionable defects.

All **six native Practice UI tests passed on iPhone 16 Pro**, using Xcode 26.6 and iOS Simulator 26.5. They cover contextual correct/incorrect grading, ordinary calls, all-in calls and raises, score retention across tabs, live-card isolation and persistent topic accuracy after relaunch. Twelve generated drills exercise all six topics at the largest system text setting. Portrait and landscape checks require every card, metric, full explanation and control to remain visible above the tab bar without scrolling, with action buttons at least 44 points tall. Exported screenshots were visually inspected. No other device model was tested for this refinement.

`git diff --check` passed. Native builds emit only the standard notice that App Intents metadata is skipped because the app has no AppIntents dependency.

### Current iPhone 16 Pro screenshots

| State | Preview |
| --- | --- |
| Checked-to actions | [Check / Bet](screenshots/practice-16pro-accessibility-choices.png) |
| Facing-bet actions | [Fold / Call / Raise](screenshots/practice-16pro-raise-question.png) |
| All-in decisions | [Call](screenshots/practice-16pro-all-in-call.png), [Raise](screenshots/practice-16pro-all-in-raise.png) |
| Numerical draw feedback | [Portrait](screenshots/practice-16pro-draw-feedback.png), [landscape](screenshots/practice-16pro-landscape-feedback.png) |

Run portable checks with `POKER_EXHAUSTIVE_TESTS=1 swift test -c release`. Run `PokerPracticeUITests` using the PokerAssistant Xcode scheme and an iPhone 16 Pro destination. Normal saved app data is isolated from test defaults.
