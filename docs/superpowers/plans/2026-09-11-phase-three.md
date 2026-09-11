# Phase 3 Implementation Plan

**Goal:** Deliver a launchable, fully offline SwiftUI poker assistant.
**Architecture:** PokerCore remains the deterministic engine; PokerUI contains native views and device-local session state. A thin iOS app target hosts PokerDashboardView.
**Spec:** `docs/superpowers/specs/2026-09-11-phase-three-design.md`

- [ ] Root: theme, numeric formatting and validation, observable persisted session, configuration sheet, dashboard integration.
- [ ] Card agent: CardTableView and CardSelectorView with same-street advance, duplicate states and accessibility.
- [ ] Action agent: ActionRecommendationView and PokerStatsView with accurate probability/amount presentation.
- [ ] Project agent: XcodeGen configuration, shared scheme, app UI tests using agreed accessibility identifiers.
- [ ] Root: app entry/icon, complete simulator build, unit and UI verification, visual checks at compact/large/accessibility sizes, independent review, README handoff.

Ownership is disjoint. Existing workspace has no Git repository. UI source uses `#if os(iOS)` so portable helper tests continue running on macOS; the actual iOS app build verifies all SwiftUI code. User approval for Phase 3 covers implementation and simulator verification. System fonts/SF Symbols replace network fonts from generic design-tool recommendations.
