# Phase 3: Riverline native iOS application

User approved Phase 3 after the Phase 2 delivery. Build a launchable SwiftUI iOS app around the verified core. Name on device: Riverline. Keep iOS 17+, Swift 6, local package dependencies only, no network or external APIs. The PokerCore module remains unchanged unless a concrete integration defect requires a targeted fix.

## Visual direction

Premium understated casino: green-black canvas, charcoal-green panels, warm ivory playing cards, muted gold highlights, pale green positive actions and coral folds. System serif headings and system sans-serif body/numeric text work fully offline. Use native SF Symbols, vector/card shapes and consistent 20/24pt panel spacing. A prominent recommendation leads the dashboard; the user's hand/community cards and live pot/call inputs follow, then the stats and strategy controls. iPad uses a bounded-width adaptive layout. Native sheets handle card picking and table setup. Honor Dynamic Type, VoiceOver, reduced motion and >=44pt touch targets.

## Flow and components

- `PokerDashboardView`: header, offline indicator, setup/new-hand buttons, action panel, card table, pot/call inputs, stats, position/situation/aggressor controls, and a short methodology sheet.
- `CardTableView`: two hole slots and five board slots. Later streets are disabled until the earlier board is complete. Tapping a slot opens `CardSelectorView`.
- `CardSelectorView`: native sheet, active-slot strip, four suit buttons, adaptive 13-rank grid. Used physical cards are visibly unavailable. A valid selection advances to another empty slot within the same street, then dismisses. Clearing an earlier street clears later streets according to the core contract. Errors are readable and selection rejection is atomic.
- `ActionRecommendationView`: large FOLD/CALL/BET/RAISE/CHECK/ALL IN label, correct chip amount and pot fraction where relevant, with expandable rationale. Incomplete/invalid states replace old advice. Recommendations never execute chip movements.
- `PokerStatsView`: required equity, approximate draw chance, specific potential outs and SPR. Use clear completion-probability labels; never mislabel Rule of 2/4 as win equity. Explain the applicable call horizon and raw-outs limitations.
- `TableSetupView`: editable bankroll, hero/opponent chips behind, big blind and advanced current-street contribution/minimum raise. Draft validation precedes applying the whole configuration. Decimal keyboards have a visible Done action.
- `PokerSession`: main-actor observable app state around PokerViewModel. Pot/call text parsing clears advice while invalid, and only validated finite states are persisted. Store versioned configuration and card selections in UserDefaults on device. Restoration revalidates card sequence/duplicates and never restores stale derived recommendations. New hand preserves balances and offers one-step Undo.

## Project and verification

Add PokerUI as a local Swift package product. iOS-only view files are conditionally compiled; portable parsing/persistence helpers have XCTest coverage on macOS. Add `PokerAssistant.xcodeproj`, reproducible `project.yml`, an app entry point, bundled icon and shared scheme. Build and run in iOS Simulator. UI tests exercise card selection and duplicate exclusion, live recommendation/stats updates, invalid input, new hand/undo, persistence and setup. Capture and inspect screenshots for a large phone, a compact phone and accessibility text. Retain the full core audit. No website or remote deployment is involved.
