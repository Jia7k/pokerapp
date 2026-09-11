# Adaptive Practice Implementation Plan

**Goal:** Implement the four accepted improvements: contextual legal actions, realistic wager construction, numerical feedback, and balanced practice that revisits missed concepts.

**Architecture:** PokerCore owns drill validation, grading, concept selection and a small Codable accuracy record. PokerUI persists that record in a separate local defaults key and presents a fixed canvas. The existing heuristic engine remains the answer source.

**Constraints:** Fully offline; two J/Q/K hole cards; unique physical cards; no visible drill counter; non-scrollable portrait/landscape; buttons at least 44 points. Native verification uses iPhone 16 Pro only. Session score remains independent of persistent topic accuracy and the saved live table.

## Core interfaces and grading

- Extend PracticeChoice with call and raise. PreparedPracticeScenario owns validation, analysis, contextual choices, mapped answer and topic. Map opening all-in to Bet, facing all-in at call cost to Call, and facing all-in above call cost to Raise. Do not offer raises when stacks or the legal minimum prevent them.
- PracticeViewModel exposes availableChoices, learningProgress and feedback topic. Submission accepts one offered choice per hand. Record accuracy once and invoke an optional persistence callback. Generated Next passes current progress into the generator.
- Explain the decisive hand assessment and calculation. Show the actual effective-stack/pot SPR for short-stack decisions, wager/pot sizing for bets, and required equity versus the appropriate draw-completion horizon for draw-price decisions. Never label draw completion as win equity.

## Generator and adaptation

- Add six topics: continuationBet, checking, shortStack, valueBet, drawPrice and facingBet. Each shuffled round covers all six; bounded bonus entries revisit topics with mistakes using smoothed error rates. Do not expose a target topic before grading.
- Generate fresh cards within each concept. Use bounded attempts and a valid constructive fallback rather than a fixed scenario bank. The shared engine must confirm the intended concept.
- Generate the pot before the opponent wager, derive the wager from that pot, subtract it from the opponent's starting stack, then add it to the displayed pot. Include ordinary bet fractions and occasional deliberate overbets. Set the initial minimum raise increment from the actual wager.
- Retain constant-size generator state and per-topic totals. Validate restored data; clamp counters before overflow and preserve reproducibility with explicit seeds.

## Persistence and interface

- Store versioned topic accuracy under a dedicated local key, using the isolated test defaults suite in UI tests. Corrupt or incompatible snapshots fall back to empty progress. Practice must never modify the saved live table.
- Render Check/Bet when checked to and Fold/Call/Raise when facing a wager, omitting unavailable actions. Use correct Call/Bet/Raise wording for all-ins in feedback. Show the topic and its saved accuracy only after answering.
- Keep FLOP as the heading and preserve the full explanation within the current fixed layout.

## Acceptance

- Core tests cover all five choices, all-in classification, unavailable actions, guarded scoring, numerical feedback, draw horizons, realistic pot/stack arithmetic, topic coverage, adaptation, seeded reproducibility and valid cards over generated batches.
- Persistence tests cover save/reload, invalid/versioned data, key isolation and retained topic accuracy with a fresh session score.
- Native iPhone 16 Pro journeys cover correct and incorrect contextual actions, facing-bet Call and Raise, absence of illegal controls, full feedback at largest text and landscape, more than twelve generated hands, plain FLOP label, and live-table isolation.
- Run the full release suite and targeted native journeys, inspect current screenshots, review the final diff and save the verified implementation.

## Completion

Implemented all four accepted improvements. The full release suite passed 159 tests, including the exhaustive five-card evaluator audit. All six native Practice journeys passed on iPhone 16 Pro (iOS Simulator 26.5), including twelve generated drills at the largest text setting, landscape, contextual Call/Raise grading and saved progress after relaunch. Current portrait and landscape screenshots were inspected; independent core/generator and persistence reviews found no actionable defects. See `docs/phase-four-delivery.md` for the final behavior and evidence.
