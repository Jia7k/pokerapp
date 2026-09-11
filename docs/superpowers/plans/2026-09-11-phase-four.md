# Phase 4 Practice Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development to implement the independent units below. Coordinate shared interfaces with the root agent.

**Goal:** Add offline face-card flop practice with instant engine-backed grading.

**Architecture:** Immutable scenario inputs and observable grading state live in PokerCore. PokerUI presents the quiz; a root TabView owns practice state separately from the existing saved live session.

**Tech Stack:** Swift 6, Observation, SwiftUI, XCTest, iOS 17+; no external packages.

**Spec:** `docs/superpowers/specs/2026-09-11-phase-four-design.md`.

## Global constraints

- Reuse Card, Deck and PostflopHeuristicEngine; do not add a parallel strategy table.
- Preserve the live PokerSession and all Phase 1–3 behavior.
- Keep Bet / Check / Fold unless the optional user clarification changes that choice.
- Score each displayed scenario once; expose no answer-derived hints before submission.
- UI actions do not execute wagers; progress is session-only.

## Task 1 — scenario validation and PracticeViewModel

Files: `Sources/PokerCore/PracticeScenario.swift`, `Sources/PokerCore/PracticeViewModel.swift`, `Tests/PokerCoreTests/PracticeViewModelTests.swift`.

- [x] Write real fixture tests for K♠Q♠ dry-board Bet, wet Check, opening-all-in Bet and expensive-draw Fold, plus invalid/unsupported input and one-shot scoring.
- [x] Run the focused suite against nonfunctional stubs and confirm behavioral failures.
- [x] Implement immutable inputs/catalog, Deck validation, engine-derived answers and guarded state transitions.
- [x] Confirm focused tests pass and report the exact public interface and checks.

## Task 2 — PracticeView

Files: `Sources/PokerUI/PracticeView.swift`; root exposes the existing `PlayingCardFace` for shared use.

- [x] Consume the agreed PracticeViewModel API; render read-only scenario inputs before submission.
- [x] Show three actions, then replace them with accessible result, engine explanation/context and Next Scenario.
- [x] Add the stable practice accessibility IDs documented in the implementation brief.
- [x] Compile for iOS 17 with the real core module; root runs simulator acceptance tests.

## Task 3 — app integration and acceptance

Files: `Sources/PokerUI/PokerRootView.swift`, `App/PokerAssistantApp.swift`, `Sources/PokerUI/CardTableView.swift`, `UITests/PokerPracticeUITests.swift`, `README.md`, delivery screenshots/report.

- [x] Add a Table/Practice TabView owning an independent PracticeViewModel and swap the app entry to it.
- [x] Add native UI tests for answer/result/Next/score, tab-state retention and live-card isolation, and compact largest-text reachability.
- [x] Run the full release unit suite and native build/UI tests; inspect screenshots and resolve actual defects.
- [x] Request an independent review of grading semantics and integration, then document the verified module and usage.
