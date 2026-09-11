# Phase 2 preflop implementation report

## Files

- `Sources/PokerCore/PreflopStrategy.swift`
- `Tests/PokerCoreTests/PreflopStrategyTests.swift`

No package configuration or other production/test sources were changed for this task.

## Implementation

- Added the public six-seat `Position`, three-bucket `StackDepth`, two-case `PreflopSituation`, canonical `StartingHand`, chart action, key, and strategy APIs from the brief.
- `StartingHand` validates exactly two distinct physical cards, normalizes card order, distinguishes pairs/suited/offsuit hands, uses `T` for ten, and exposes all 169 classes.
- `StackDepth.nearest(to:)` rejects nonpositive/nonfinite inputs, resolves 30 and 70 BB ties toward the shallower bucket, and handles values outside the bucket interval with explicit endpoint selection. Explicit endpoint checks also avoid loss-of-precision errors for very large finite `Double` values.
- The strategy begins with all 6,084 keys set to deliberate defaults, then expands explicit range strings for every depth and position. Unopened non-BB range hands raise 2.5 BB; an unopened BB always checks. Facing-open presets contain calls and three-bets, with 3x sizing outside the blinds and 4x sizing in SB/BB.
- Source comments identify the charts as GTO-inspired simplified six-seat presets rather than solver charts, and document that opener position/range plus multiway, limped, and re-raised pots are outside the model.

## Test-first evidence

The initial filtered run failed at compile time because the new public preflop types did not exist. After implementation, the isolated preflop target passed all 15 tests.

A boundary review then found that `Double.greatestFiniteMagnitude` could make all absolute bucket distances compare equal. A new regression assertion was added first and observed failing with `bb20` instead of `bb100`. Explicit endpoint handling was then implemented and the workspace filtered test command passed:

```text
Test Suite 'PreflopStrategyTests' passed
Executed 15 tests, with 0 failures (0 unexpected)
```

Command:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/pokerapp-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/pokerapp-module-cache swift test --scratch-path /private/tmp/pokerapp-preflop-build --cache-path /private/tmp/pokerapp-swift-cache --config-path /private/tmp/pokerapp-swift-config --security-path /private/tmp/pokerapp-swift-security --disable-sandbox --filter PreflopStrategyTests
```

Coverage includes all 1,326 physical two-card combinations mapping into 169 canonical classes, reverse-order/pair/suited/offsuit/ten notation, invalid cards/counts, all 6,084 chart keys, depth boundaries and invalid values, BTN A5s at 40 BB, early/late and depth-sensitive decisions, calls, premium three-bets, positional three-bet sizing, BB checks, and deliberate folds.

## Decisions and concerns

The presets are internally consistent and deterministic, but intentionally approximate. They do not condition facing-open defense on the opener's position or range, and they do not model limped, multiway, or re-raised pots.

A full-suite run compiled all current sources and passed the preflop suite plus the completed core/postflop suites. It remained red only in the concurrently in-progress `PokerViewModelTests` (45 failures); this task did not modify those owned files. The root agent was notified with the exact scope of those failures.
