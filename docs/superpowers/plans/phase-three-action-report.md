# Phase 3 recommendation and statistics UI report

Implemented the assigned iOS-only SwiftUI views:

- `ActionRecommendationView` presents every `PokerAction` with the required semantic color, amount semantics, actual bet-to-pot fraction, street label, incomplete/invalid/no-action states, scalable headline, Reduce Motion-aware reasoning disclosure, and stable action accessibility identifiers. Recommendations are display-only.
- `PokerStatsView` uses a 2x2 metric grid that becomes one column at accessibility sizes. It separates required equity, Rule of 2/4 completion estimates, exact next-card/call-horizon context, potential outs, and SPR. Missing input, a completed river, and zero listed outs have distinct values and explanations. Specific out cards use an adaptive disclosure grid with spoken card names; board texture and paired state appear in the footer.

Verification:

- `swiftc -frontend -parse` passed for both owned source files.
- An iOS 17 simulator-SDK typecheck passed for the owned views with `PokerCore`, `PokerTheme`, and `PokerFormat`.
- The same simulator-SDK typecheck passed for all current `PokerUI` sources.

No simulator was started and no implementation-mirroring UI unit tests were added, per the task brief. Root still owns final formatter behavior, app build, screenshots, and UI tests; at report time `PokerFormat.percent` remains in its announced test-first stub state.

## Table setup supplement

Added `TableSetupView` as an iOS-only `NavigationStack` and dark-themed `Form`. All eight values edit a local `TableSetupDraft`, so Cancel cannot mutate the session. The Save action validates the complete draft, applies it atomically through `PokerSession`, and dismisses only after success; invalid drafts disable Save and show the validation message. Every decimal field uses a vertically stacked label/value layout, the requested accessibility identifier, and a keyboard Done action. Bankroll, remaining stacks, current pot/call values, and advanced street settings are separated with concise chip-model guidance. Changing the big blind also updates the minimum raise when it still matches the previous blind.

Fresh verification passed for `swiftc -frontend -parse`, the focused iOS 17 simulator-SDK typecheck with the setup dependencies, and the simulator-SDK typecheck of all current `PokerUI` sources. Root still owns the in-progress implementations of `TableSetupDraft.validated` and `PokerSession.applyConfiguration`; end-to-end setup behavior depends on those helpers and the final app/UI-test pass.
