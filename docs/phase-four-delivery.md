# Phase 4 — GTO Practice Tool

The Practice tab presents ten offline face-card flop drills without changing the saved live table. The first is K♠ Q♠ on A♥ 8♦ 2♣ with a 100-chip pot and 400-chip effective stack.

## Model and grading

`Sources/PokerCore/PracticeScenario.swift` holds immutable scenario inputs and the curated catalog. Each loaded drill validates its cards with `Deck` and obtains its recommendation from `PostflopHeuristicEngine`.

`Sources/PokerCore/PracticeViewModel.swift` owns the current drill, one-shot submission, immutable feedback, running score and Next Scenario transition. It rejects unsupported answers and invalid inputs instead of silently substituting a different decision. No answer key is stored in the catalog.

The requested Bet / Check / Fold interface includes checked-to bets, opening all-ins, checks and folds facing a wager. Calls and raises are outside this bank. Facing a bet, Check and literal Bet are illegal choices and receive explanatory incorrect feedback. An opening all-in maps to Bet; an all-in call does not. The tool tests agreement with the app's simplified heuristics, not a GTO solver.

## Interface and integration

`Sources/PokerUI/PracticeView.swift` reuses the casino palette, card faces and number formatting. Before submission, it shows only the drill inputs. After submission, it replaces the action buttons with CORRECT/INCORRECT, recommended sizing, an engine-derived explanation, board texture, SPR and Next Scenario.

`Sources/PokerUI/PokerRootView.swift` owns the practice model separately from `PokerSession`. Switching tabs preserves the current drill and score; restarting the app begins a fresh practice session. Large text uses vertical layouts, and all actions are scrollable with VoiceOver labels.

## Verification

Verified on 2026-09-11 with Swift 6.3.3, Xcode 26.6 and iOS Simulator 26.5:

- **131 release unit tests passed**, including 14 new practice tests and the exhaustive audit of all 2,598,960 five-card combinations and 7,462 distinct hand values.
- **All six native UI journeys passed on iPhone 17 Pro**, covering existing table behavior plus practice. The three practice journeys also passed on iPhone SE.
- Practice journeys exercise correct/incorrect grading, hidden pre-answer analysis, button replacement, score retention, Next Scenario, live-card isolation and largest accessibility text sizes.
- Independent core and UI review found no actionable defects. `git diff --check` passed.

The compact-screen check exposed full-swipe overshoot in the UI test helper. Recorded frames showed Fold was skipped between visible Bet/Check controls and the footer. Bounded drags now bring each complete button above the floating tab bar; both devices passed with the actual view unchanged.

Run the portable checks with `POKER_EXHAUSTIVE_TESTS=1 swift test -c release`. Run native journeys using Product → Test in the PokerAssistant Xcode scheme. Test defaults are isolated from the normal app's saved session.

## Screenshots

| Screen | Preview |
| --- | --- |
| First face-card drill | [Question](screenshots/practice-question.png) |
| Bet / Check / Fold controls | [Choices](screenshots/practice-choices.png) |
| Correct continuation bet | [Correct result](screenshots/practice-correct.png) |
| Incorrect check with a made straight | [Incorrect result](screenshots/practice-incorrect.png) |
| iPhone SE, largest accessibility text | [Choices](screenshots/practice-se-accessibility-choices.png), [feedback](screenshots/practice-se-accessibility-feedback.png) |
