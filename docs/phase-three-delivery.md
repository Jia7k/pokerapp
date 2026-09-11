# Phase 3 delivery — Riverline

Riverline is a launchable, offline SwiftUI iPhone/iPad app. Open `PokerAssistant.xcodeproj`, choose the PokerAssistant scheme and a simulator, and Run. A physical device requires the user's development team in Signing & Capabilities. The project uses only the local PokerCore and PokerUI package products.

## Delivered

- Suit/rank card selector with duplicate blocking, same-street advancement, and turn/river gating.
- Dark dashboard with prominent actions, legal wager amounts, live pot/call entry, specific completion cards, odds, board texture and strategy context.
- Cancellable table setup for bankroll, remaining stacks, blinds and advanced street values.
- Validated local session persistence, automatic recomputation on restore, and one-step new-hand undo.
- Dynamic Type, VoiceOver labels, 44-point controls, reduced-motion handling and a reproducible native app icon.

Small nonzero values retain their meaning. Invalid live text clears recommendations without replacing the last valid saved state. Chip balances remain manually recorded; recommendations do not execute bets.

## Verification

Environment: Xcode 26.6, Swift 6.3.3, iOS Simulator 26.5, iOS 17 deployment target.

| Check | Result |
| --- | --- |
| Release package suite, exhaustive evaluation enabled | 117 tests passed |
| Five-card audit | All 2,598,960 combinations and 7,462 distinct values checked |
| Session, parsing, restore and undo tests | 9 passed, included in the 117 |
| Native app and XCTest build | Passed |
| iPhone 17 Pro UI journeys | 3 passed: flop/advice, persistence/setup/undo, largest Dynamic Type |
| iPhone SE accessibility journey | Passed after final accessibility layout refinements |
| Independent state/semantic review | No unresolved findings |

The screenshots in `screenshots/` are actual simulator captures. Normal-sized card and statistic panels, compact-phone layout, and the largest accessibility text size were visually inspected. Offscreen content remains reachable through native scrolling.

To repeat engine verification:

```sh
POKER_EXHAUSTIVE_TESTS=1 swift test -c release
```

To repeat simulator journeys, use Product → Test in the PokerAssistant Xcode scheme. UI tests use an isolated UserDefaults suite. Their reset flag never clears production app preferences.

## Scope

Preflop presets are GTO-inspired simplifications. Postflop advice uses heuristics and the applicable draw horizon. Potential outs are exact under the documented completion definition; draw percentages are not showdown win equity. The app does not model multiway side pots or opponent ranges. See the root README for the mathematical conventions.

Physical-device signing and App Store publication were not performed.
