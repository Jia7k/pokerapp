# Unlimited Practice Refinement

Replace the default ten-hand cycle with an on-demand randomized stream while keeping the existing fixed, non-scrollable screen and face-card focus. Verify native behavior only on iPhone 16 Pro, as requested.

## Implementation

- Generate two J/Q/K hole cards without replacement and draw a fresh three-card flop from the remaining `Deck`.
- Randomize valid chip amounts, effective stacks, preflop initiative and facing-bet context. Use the existing engine to accept only recommendations expressible by Bet / Check / Fold.
- Bound rejection attempts and retain a checked-to fallback built from a fresh random deal. Keep generator memory bounded and use seedable randomness for reproducible tests.
- Default `PracticeViewModel()` to generation; preserve explicit catalog injection for fixtures. Keep one accepted answer per drill, guard Next until grading, retain score across tabs, and increment the generated drill number without a catalog reset.
- Remove the finite total from generated progress labels. Use a seed only when UI testing is explicitly enabled; normal sessions use system randomness.

## Acceptance

- Deterministic tests cover seed replay, varied cards/betting contexts/answers, valid physical cards, engine agreement, continued generation beyond ten, guarded scoring and bounded generation.
- iPhone 16 Pro native tests cover grading, next/score retention, live-table isolation, twelve generated drills at largest system text, and landscape. Assert all cards, amounts, explanation and buttons fit above the tab bar without scrolling, including long incorrect-Bet feedback facing a wager.
- Review the diff and capture current iPhone 16 Pro screenshots before recording verified results in the delivery notes.

## Completion

Implemented and verified on 2026-09-11: 138 release unit tests and all four iPhone 16 Pro Practice UI tests passed. Independent review found no actionable issues. See `docs/phase-four-delivery.md` for the algorithm, verification details and current screenshots.
