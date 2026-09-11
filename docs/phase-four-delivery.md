# Phase 4 — GTO Practice Tool

The Practice tab generates an unlimited stream of randomized offline face-card flop drills without changing the saved live table. Each Next Scenario produces another deal instead of cycling after ten.

## Model and grading

`Sources/PokerCore/PracticeScenarioGenerator.swift` samples two J/Q/K hole cards without replacement, shuffles the remaining `Deck`, and draws three flop cards. It varies valid pots, stacks, preflop initiative and facing-bet context. Each candidate obtains its recommendation from `PostflopHeuristicEngine` before it can become a drill.

Generation tries at most four randomized candidates, followed by one checked-to fallback using the last random deal. It never falls back to the old catalog or retains a growing scenario history. Accepted engine analysis is cached for grading. A SplitMix64 generator is initialized from system randomness normally; an explicit seed allows tests to replay the same generated session. Unlimited means no fixed session limit, not a guarantee that finite card combinations never recur.

Pot sizes range from 80 to 600 chips at a 10-chip big blind. Covered-stack ratios are sampled from 0.5, 0.75, 1, 2, 4 and 6, with an optional extra stack on one player. Outstanding bets vary between 25%, 50% and 75% of the displayed pot. The existing betting model computes the final effective stack and SPR, including the outstanding wager.

`Sources/PokerCore/PracticeScenario.swift` retains immutable inputs and the original curated catalog for explicit fixture injection, including K♠ Q♠ on A♥ 8♦ 2♣. It is no longer the default source of drills.

`Sources/PokerCore/PracticeViewModel.swift` owns the current drill, one-shot submission, immutable feedback, running score and Next Scenario transition. It rejects unsupported answers and invalid inputs instead of silently substituting a different decision. No answer key is stored in the catalog.

The requested Bet / Check / Fold interface includes checked-to bets, opening all-ins, checks and folds facing a wager. Calls and raises are outside this mode. Facing a bet, Check and literal Bet are illegal choices and receive explanatory incorrect feedback. An opening all-in maps to Bet; an all-in call does not. This filters the generated situations for the three-choice interface; it is not a uniform sample of all poker decisions. The tool tests agreement with the app's simplified heuristics, not a GTO solver.

## Interface and integration

`Sources/PokerUI/PracticeView.swift` reuses the casino palette, card faces and number formatting. Before submission, it shows only the drill inputs. After submission, it replaces the action buttons with CORRECT/INCORRECT, recommended sizing, an engine-derived explanation, board texture, SPR and Next Scenario.

`Sources/PokerUI/PokerRootView.swift` owns the practice model separately from `PokerSession`. Switching tabs preserves the current drill and score; restarting the app begins a fresh practice session. The community-card heading is simply FLOP, with no drill number or total. The app accepts a deterministic practice seed only when launched in UI-test mode.

Following the requested layout refinement, Practice uses a fixed canvas without a scroll view. Geometry scales the cards, fonts and spacing; portrait stacks the compact context and answer panels, while landscape places them side by side. Controls retain at least 44-point heights. Typography growth is bounded to fit the screen, with complete card and feedback descriptions retained for VoiceOver.

## Randomized-drill verification

On 2026-09-11, **138 release unit tests passed**, including the exhaustive five-card evaluator audit and 21 practice tests. Seven new generator tests cover a 160-deal batch, all three answers and board textures, seeded replay/divergence, valid cards and betting states, checked-to fallback, progression beyond ten, and guarded scoring. Independent code review found no actionable defects.

**All four native Practice UI tests passed on iPhone 16 Pro**, using Xcode 26.6 and iOS Simulator 26.5. They cover correct/incorrect grading, score retention across tabs, live-card isolation, landscape, and twelve generated drills at the largest system text setting. The session advances beyond twelve drills with the expected score. All cards, metrics, actions and full explanations stay above the tab bar without scrolling, with buttons at least 44 points tall. Exported portrait and landscape screenshots were visually inspected. No other device model was tested for this refinement.

### iPhone 16 Pro screenshots

After removing the visible and VoiceOver drill counter, the twelve-drill UI test was rerun on iPhone 16 Pro and passed. These screenshots show the plain FLOP heading.

| Screen | Preview |
| --- | --- |
| Largest system text | [Choices](screenshots/practice-16pro-accessibility-choices.png), [long feedback](screenshots/practice-16pro-long-feedback.png) |
| Generated straight and value bet | [Sizing feedback](screenshots/practice-16pro-value-bet.png) |

## Earlier verification

Verified on 2026-09-11 with Swift 6.3.3, Xcode 26.6 and iOS Simulator 26.5:

- **Engine baseline: 131 release unit tests passed** during Phase 4, including 14 practice tests and the exhaustive audit of all 2,598,960 five-card combinations and 7,462 distinct hand values. The single-screen refinement makes no engine changes.
- **All four updated Practice UI journeys passed on both iPhone 17 Pro and iPhone SE**: eight successful test executions for the fixed layout.
- Checks cover every card, table value, choice and complete feedback in all ten drills at the largest system text setting; landscape, correct/incorrect grading, score retention, Next Scenario and live-card isolation also pass. Buttons have at least 44-point heights and remain above the tab bar. No Practice scrolling is used by the tests.
- Independent core and UI review found no actionable defects. `git diff --check` passed.

These are historical results for the curated catalog and preceding layout refinement. The randomized-drill results above supersede them for the current Practice screen.

Run the portable checks with `POKER_EXHAUSTIVE_TESTS=1 swift test -c release`. Run native journeys using Product → Test in the PokerAssistant Xcode scheme. Test defaults are isolated from the normal app's saved session.

## Earlier catalog screenshots

| Screen | Preview |
| --- | --- |
| First face-card drill | [Question](screenshots/practice-question.png) |
| Bet / Check / Fold controls | [Choices](screenshots/practice-choices.png) |
| Correct continuation bet | [Correct result](screenshots/practice-correct.png) |
| Incorrect check with a made straight | [Incorrect result](screenshots/practice-incorrect.png) |
| iPhone SE, largest accessibility text | [Choices](screenshots/practice-se-accessibility-choices.png), [feedback](screenshots/practice-se-accessibility-feedback.png) |
| iPhone SE, longer explanation | [Full fold feedback](screenshots/practice-se-long-feedback.png) |
| iPhone SE, landscape | [Question](screenshots/practice-se-landscape-question.png), [feedback](screenshots/practice-se-landscape-feedback.png) |
