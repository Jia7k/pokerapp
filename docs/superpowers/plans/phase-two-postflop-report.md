# Phase Two Postflop Report

## Implemented

- Added `BoardTextureAnalyzer` for 3...5 unique board cards. It reports pairing, maximum suit count, and connectivity across every legal five-rank straight window, including the ace-low wheel without ace-to-king wraparound.
- Added `MadeHandAssessment` using `HandEvaluator` plus category-rank participation from hero's hole cards. Board pair, trips, and quads do not become hero strength through a kicker. River `playsBoard` compares the complete hand value, so a hole-card kicker improvement is represented accurately without treating it as category participation.
- Added the ordered postflop heuristic: terminal stack handling, short-stack commitment, facing-bet decisions, dry-flop continuation bets, strong value bets, and free checks.
- Delegated every call, bet, raise, all-in, minimum-wager, and coverage decision to `BettingState` helpers.
- Kept Rule-of-2/4 completion estimates separate from decision probabilities. Ordinary flop calls and every turn call use exact next-card completion probability; a flop call that closes betting uses Rule of 4; river values are nil. The displayed turn approximation remains Rule of 2.
- Added short explanations and explicit notes that the subsystem is a simplified heads-up heuristic, does not model an opponent range, and does not provide true win equity.
- Preserved category participation separately from top-pair strength, so a hero-contributed middle or bottom pair checks as `.checkWithoutValue` rather than being mislabeled as board-only.
- Added deterministic guaranteed-split detection on the river by checking every legal opponent holding against the shared board value. Unbeatable board values call or check with `.guaranteedSplit`; ordinary board straights and flushes remain subject to the normal decision rules.
- Recommendation metadata is chosen after `BettingState.sizedBet` returns. If opponent coverage cannot support the legal minimum wager and the helper returns `.check`, the result uses `.insufficientCoverage` and explains the check.

## Test-first evidence

The initial focused run failed before production code existed, with the expected missing `BoardTextureAnalyzer`, `PostflopAnalysis`, and `PostflopHeuristicEngine` symbols. At that moment, unrelated `PreflopStrategyTests` also could not compile because their independently owned implementation was still in its red phase.

After initial implementation, the required isolated command passed all 22 postflop tests with zero failures. Review regressions were then established before each corresponding fix, bringing focused coverage to 29 tests.

```text
Test Suite 'PostflopHeuristicTests' passed
Executed 29 tests, with 0 failures (0 unexpected)
```

Coverage includes dry, wet, monotone, paired, ace-low, and non-wrapping boards; whole-board turn and river texture; count and duplicate validation; top-pair and category-participation traps; hero-contributed middle pair; improved board full houses; board-played straights; exact guaranteed-split positives and negatives; low-SPR commitment; helper sizing and insufficient-coverage checks; ordinary and closing flop call horizons; exact turn call pricing alongside the displayed Rule of 2; facing-bet priority; river made hands with zero outs; continuation bets; free checks; and terminal stack states.

## Decisions and limits

- `playsBoard` follows the exact full-value definition. On `KKKK2` with an ace hole-card kicker, it is false because the ace improves the five-card value, while `isStrongMadeHand` remains false because hero did not contribute to the quads rank.
- A checked board-supplied pair-or-better category uses `.boardOnlyHand` even when a hole kicker improves the full value. Hero-contributed lower pairs use `.checkWithoutValue`. This keeps category participation distinct from both top-pair strength and `playsBoard`.
- Guaranteed split detection enumerates possible opponent holdings only to prove that none can exceed the board value. It assigns no ranges, weights, or win-equity estimate. The added exhaustive river check costs roughly 0.1 seconds in focused debug tests for a guaranteed board.
- With no outstanding call, `decisionDrawProbability` is nil because there is no call horizon to price. `approximateDrawProbability` remains available on flop and turn.
- Outs retain the existing `OutsCalculator` contract: they are category-upgrade completion cards, not clean equity-adjusted outs. Backdoors, overcards, same-category improvements, opponent ranges, redraws, and counterfeit risk remain outside this bounded heuristic.

## Integration status

The focused postflop suite passed after the shared `BettingState` implementation and the independently owned preflop source became available. The complete package suite was intentionally left to the root integrator while `PokerViewModel` was being implemented concurrently.
