# Phase 4 — GTO Practice Tool

The Practice tab presents ten offline face-card flop drills without changing the saved live table. The first is K♠ Q♠ on A♥ 8♦ 2♣ with a 100-chip pot and 400-chip effective stack.

## Model and grading

`Sources/PokerCore/PracticeScenario.swift` holds immutable scenario inputs and the curated catalog. Each loaded drill validates its cards with `Deck` and obtains its recommendation from `PostflopHeuristicEngine`.

`Sources/PokerCore/PracticeViewModel.swift` owns the current drill, one-shot submission, immutable feedback, running score and Next Scenario transition. It rejects unsupported answers and invalid inputs instead of silently substituting a different decision. No answer key is stored in the catalog.

The requested Bet / Check / Fold interface includes checked-to bets, opening all-ins, checks and folds facing a wager. Calls and raises are outside this bank. Facing a bet, Check and literal Bet are illegal choices and receive explanatory incorrect feedback. An opening all-in maps to Bet; an all-in call does not. The tool tests agreement with the app's simplified heuristics, not a GTO solver.

## Interface and integration

`Sources/PokerUI/PracticeView.swift` reuses the casino palette, card faces and number formatting. Before submission, it shows only the drill inputs. After submission, it replaces the action buttons with CORRECT/INCORRECT, recommended sizing, an engine-derived explanation, board texture, SPR and Next Scenario.

`Sources/PokerUI/PokerRootView.swift` owns the practice model separately from `PokerSession`. Switching tabs preserves the current drill and score; restarting the app begins a fresh practice session.

Following the requested layout refinement, Practice uses a fixed canvas without a scroll view. Geometry scales the cards, fonts and spacing; portrait stacks the compact context and answer panels, while landscape places them side by side. Controls retain at least 44-point heights. Typography growth is bounded to fit the screen, with complete card and feedback descriptions retained for VoiceOver.

## Verification

Verified on 2026-09-11 with Swift 6.3.3, Xcode 26.6 and iOS Simulator 26.5:

- **Engine baseline: 131 release unit tests passed** during Phase 4, including 14 practice tests and the exhaustive audit of all 2,598,960 five-card combinations and 7,462 distinct hand values. The single-screen refinement makes no engine changes.
- **All four updated Practice UI journeys passed on both iPhone 17 Pro and iPhone SE**: eight successful test executions for the fixed layout.
- Checks cover every card, table value, choice and complete feedback in all ten drills at the largest system text setting; landscape, correct/incorrect grading, score retention, Next Scenario and live-card isolation also pass. Buttons have at least 44-point heights and remain above the tab bar. No Practice scrolling is used by the tests.
- Independent core and UI review found no actionable defects. `git diff --check` passed.

The single-screen acceptance checks require all cards, chip values, actions, feedback and Next Scenario to be fully visible above the tab bar without any scrolling. They exercise all ten drills at the largest system text setting, including long fold feedback, plus landscape and live-table isolation.

Run the portable checks with `POKER_EXHAUSTIVE_TESTS=1 swift test -c release`. Run native journeys using Product → Test in the PokerAssistant Xcode scheme. Test defaults are isolated from the normal app's saved session.

## Screenshots

| Screen | Preview |
| --- | --- |
| First face-card drill | [Question](screenshots/practice-question.png) |
| Bet / Check / Fold controls | [Choices](screenshots/practice-choices.png) |
| Correct continuation bet | [Correct result](screenshots/practice-correct.png) |
| Incorrect check with a made straight | [Incorrect result](screenshots/practice-incorrect.png) |
| iPhone SE, largest accessibility text | [Choices](screenshots/practice-se-accessibility-choices.png), [feedback](screenshots/practice-se-accessibility-feedback.png) |
| iPhone SE, longer explanation | [Full fold feedback](screenshots/practice-se-long-feedback.png) |
| iPhone SE, landscape | [Question](screenshots/practice-se-landscape-question.png), [feedback](screenshots/practice-se-landscape-feedback.png) |
