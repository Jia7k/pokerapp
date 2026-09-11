# Recommendation and statistics UI task

Read Phase 3 spec, PokerCore/PokerViewModel.swift and BettingState.swift. Own only `Sources/PokerUI/ActionRecommendationView.swift` and `Sources/PokerUI/PokerStatsView.swift`. Wrap view files in `#if os(iOS)`, import SwiftUI and PokerCore. No other file edits or subagents.

Public interfaces:
```swift
@MainActor public struct ActionRecommendationView: View {
  public init(analysis: PokerAnalysis, pot: Double)
}
@MainActor public struct PokerStatsView: View {
  public init(analysis: PokerAnalysis)
}
```
Use PokerTheme semantic colors, `casinoPanel()` and CasinoButtonStyle from same module. Root will implement `PokerFormat.chips(_ value: Double) -> String`, `PokerFormat.percent(_ value: Double?) -> String`, `PokerFormat.ratio(_ value: Double?) -> String`, `PokerFormat.street(_ street: Street?) -> String`, `PokerFormat.cardName(_ card: Card) -> String`. Do not redeclare these.

Visual: prominent editorial action card with subtle green felt-like surface via native gradient (no external assets), warm ivory large serif/sans type, gold/green/coral accents. Clear `RECOMMENDED PLAY` kicker and street label. FOLD coral; CALL gold; BET/RAISE/ALL IN green; CHECK neutral/gold. Show big action and correct amount. `.bet(amount)` may show BET 33% if actual amount/pot ratio is finite; if capped, show actual percentage, not the original target33. `.raise(to)` means total street contribution, while call/bet/allIn amounts are additional. No action is an executed button. Expandable explanation/recommendation notes for rationale. Nil/incomplete -> 'ADD YOUR CARDS' with clear next step, invalid -> 'CHECK INPUT' with analysis.message, noAction -> 'WAIT FOR BOARD'. No stale action. Dynamic Type should wrap; use ScaledMetric for large display size, avoid hard clipping.

Stable accessibility: action title Text id `action.title`; amount Text if present `action.amount`; explanation toggle `action.reason`. Leave these leaf texts exposed to XCUI, not hidden under a combined parent accessibility element.

Stats: 2x2 metric layout for Pot odds (required equity), Draw chance (Rule2/4, explicit approximation), Potential outs, and SPR. Numeric Text IDs `stats.potOdds`, `stats.drawChance`, `stats.outs`, `stats.spr`. Nil -> em dash, never fake0. Show exact next-card/call-horizon value when available without confusing it with Win%. Include specific outs cards as legible rank+suit chips in an adaptive grid/disclosure; duplicate count already handled by core. Label examples 'Completion estimate, not win equity' and explain incomplete/river states concisely. Specific cards need accessible names. Three conditions are distinct: no future river draw;0known completionouts;missing input. Board texture label dry/rainbow,wet/connected,monotone and paired flag can appear in a compact footer. Do not use color as sole meaning. Avoid overloading the view with all engine implementation details.

Root handles controls/session/persistence/app target and will build/run screenshots/UI tests. UI-only views need no implementation-mirroring unit tests; report source/build concerns. Write concise report `docs/superpowers/plans/phase-three-action-report.md` when done. Do not start simulators yourself.
