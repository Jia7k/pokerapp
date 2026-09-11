# Card UI task

Read the Phase 3 design spec and Sources/PokerCore/PokerViewModel.swift. Own only `Sources/PokerUI/CardTableView.swift` and `Sources/PokerUI/CardSelectorView.swift`. Wrap whole view files in `#if os(iOS)`. Import SwiftUI and PokerCore. No Package.swift changes or extra agents. Root owns Theme, formatting, dashboard and session; other agents own recommendation/stats/project.

Public interfaces:
```swift
@MainActor public struct CardTableView: View {
  public init(model: PokerViewModel, onSelect: @escaping (CardSlot) -> Void)
}
@MainActor public struct CardSelectorView: View {
  public init(model: PokerViewModel, initialSlot: CardSlot, onSelection: @escaping () -> Void = {})
}
```

Use PokerTheme tokens already present. `casinoPanel()` and `CasinoButtonStyle` are internal in the same module. Root will provide portable formatting helpers `PokerFormat.cardName(_ card: Card) -> String`, `PokerFormat.slotName(_ slot: CardSlot) -> String`, `PokerFormat.slotID(_ slot: CardSlot) -> String` returning `hole.0`, `flop.0`, `turn`, etc. Do not redefine them.

Card table: polished native ivory playing card faces, dark/red suit glyphs, rank at corners, outlined empty slots. Two hero cards above five board cards. Visually group the first three as Flop, then Turn and River. Current hand name can sit beside hero cards. Layout must fit a 375pt iPhone and support landscape/iPad and Dynamic Type; avoid GeometryReader with an unbounded vertical height. >=44pt hit regions. Board turn/river buttons disabled until prerequisite board cards are selected. Buttons IDs `card.hole.0`, `card.hole.1`, `card.flop.0`, `card.flop.1`, `card.flop.2`, `card.turn`, `card.river`. Labels describe slot and card, not Unicode alone. Empty displays are clean/dashed, not an image asset.

Card selector: NavigationStack sheet with Done/Close, active slot selector strip, four suit controls and a 13-rank adaptive grid (descending A,K,Q,J,10...2) for the current suit. Rank cells >=44pt and visibly selected/unavailable. Use model.availableCards(for:) to keep current choice available while disabling other used cards. Suit IDs `selector.suit.spades`, `.hearts`, `.diamonds`, `.clubs`; rank IDs `selector.rank.14` through `selector.rank.2`. Active slot text ID `selector.activeSlot`; dismiss button ID `selector.done`; clear current ID `selector.clear`. Full descriptive VoiceOver labels.

On valid selection use model.setCard; call onSelection(); advance to the next empty hole slot if selecting holes, or next empty flop slot if selecting flop, otherwise dismiss when that street is complete. Never auto-advance from holes into flop or from flop into turn. Valid edit with already-complete street dismisses. Selecting same card may dismiss normally. Allow selecting another valid slot via strip, but disable unavailable later streets. Clear follows core behavior, remains in sheet and shows contextual note if it will remove turn/river. Catch/show errors near input. Use `.sensoryFeedback(.selection, trigger: ...)` if suitable, not UIKit globals; respect Reduce Motion. Do not add preview-only fake models to production.

UI-only changes do not need mirror unit tests; verify via source typecheck/build when possible and root will exercise actual UI tests/screenshots. Builds may initially fail because other view files are still under construction; communicate rather than editing others' files. Write report `docs/superpowers/plans/phase-three-card-report.md`, concise status and any concerns. Do not start app/simulators yourself; root owns visual verification.
