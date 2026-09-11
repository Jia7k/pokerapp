# Riverline — Offline Poker Assistant

A native SwiftUI Texas Hold’em assistant with an offline Swift engine, hardcoded preflop ranges, postflop heuristics, card selection, table setup, saved sessions and face-card practice drills. There are no external packages, APIs, accounts, analytics, downloaded assets or network calls.

Requires Swift 6 / Xcode 16 or later. The iPhone/iPad app targets iOS 17+. Portable engine and session tests also run on macOS 14+.

## Run the iOS app

1. Open `PokerAssistant.xcodeproj` in Xcode.
2. Select the **PokerAssistant** scheme and an iPhone or iPad simulator, then Run.
3. For a physical device, select your development team in the app’s Signing & Capabilities settings.

The app is named **Riverline** on the Home Screen. The generated project is checked in; XcodeGen is only needed when changing its definition. Regenerate it with `xcodegen generate` using `project.yml` (XcodeGen 2.46+).

Set your bankroll, chips behind and blind in **Table setup**. Tap a hole-card slot, choose a suit and rank, then enter the flop, turn and river as they arrive. Selected cards cannot be duplicated. Pot includes the outstanding opposing bet; amount to call is the additional amount you face. Update actual balances yourself after a hand. **New hand** clears the current cards and street inputs, with a one-step Undo.

Session values and cards save locally with `UserDefaults`; restored cards are validated and advice is recalculated. Invalid numeric text clears advice and preserves the last valid disk snapshot. A corrupt or incompatible saved snapshot falls back to an empty hand. Bankroll is a separate session record from the remaining table stacks.

## SwiftUI layer

| File | Responsibility |
| --- | --- |
| `Sources/PokerUI/PokerRootView.swift` | Table and Practice tabs with independent state |
| `Sources/PokerUI/PokerDashboardView.swift` | Main dashboard, live pot/call input and strategy controls |
| `Sources/PokerUI/PracticeView.swift` | Face-card quiz, instant grading, explanation and score |
| `Sources/PokerUI/CardTableView.swift` | Hole, flop, turn and river card slots |
| `Sources/PokerUI/CardSelectorView.swift` | Suit/rank picker, duplicate prevention and street progression |
| `Sources/PokerUI/ActionRecommendationView.swift` | Prominent action, sizing and expandable reasoning |
| `Sources/PokerUI/PokerStatsView.swift` | Pot odds, completion estimates, specific outs and texture |
| `Sources/PokerUI/TableSetupView.swift` | Validated, cancellable table setup |
| `Sources/PokerUI/PokerSession.swift` | Local persistence and new-hand undo |
| `Sources/PokerUI/TableConfiguration.swift` | Atomic configuration validation |
| `Sources/PokerUI/PokerTheme.swift` | Dark casino palette and shared styling |
| `App/PokerAssistantApp.swift` | App entry point |

The interface uses system typography and native SwiftUI controls, supports Dynamic Type and VoiceOver labels, and respects Reduce Motion. UI test state uses a separate defaults suite and never clears normal app data.

## Files

| File | Responsibility |
| --- | --- |
| `Sources/PokerCore/Card.swift` | Rank 2–A, four Unicode suits, immutable card identity, Codable persistence |
| `Sources/PokerCore/Deck.swift` | Unique 52-card deck, known-card exclusion, shuffle and draw |
| `Sources/PokerCore/HandEvaluator.swift` | Best five-card value from 5–7 cards; all nine categories and every kicker |
| `Sources/PokerCore/OutsCalculator.swift` | Enumerate specific next-card made-hand completions without double-counting |
| `Sources/PokerCore/PokerMath.swift` | Pot odds, betting streets, Rule of 2 and 4 |
| `Sources/PokerCore/PokerInputError.swift` | Typed validation errors |
| `Sources/PokerCore/PreflopStrategy.swift` | All 169 starting hands and a complete position/depth/situation dictionary |
| `Sources/PokerCore/BettingState.swift` | Stack coverage, callable pot, legal wager sizing and recommendation values |
| `Sources/PokerCore/PostflopHeuristicEngine.swift` | Board texture, hero-owned made hands and ordered action rules |
| `Sources/PokerCore/PokerViewModel.swift` | Main-actor observable inputs, validated card slots and derived analysis |
| `Sources/PokerCore/PracticeScenario.swift` | Immutable drill inputs and optional curated fixtures |
| `Sources/PokerCore/PracticeScenarioGenerator.swift` | Seedable, on-demand randomized face-card drills using Deck and the existing engine |
| `Sources/PokerCore/PracticeViewModel.swift` | One-shot grading, feedback, unlimited progression and session score |

## Run and integrate

Open `Package.swift` in Xcode and run the PokerAssistant package tests, or use:

```sh
swift test
```

For the exhaustive five-card audit:

```sh
POKER_EXHAUSTIVE_TESTS=1 swift test -c release
```

That audit checks all **2,598,960** five-card combinations, all nine category totals, and the **7,462** distinct category/tiebreak values. It is skipped during regular tests to keep iteration quick. Focused tests cover seven-card selection, wheels, double trips, kickers, board play, overlapping draws, dead cards, pot odds and invalid input.

To integrate elsewhere, add this folder as a local Swift package dependency, select `PokerCore` for the engine or `PokerUI` for the native views, and import the selected product. The included app already uses this local package.

Run the native UI journeys with Product → Test in the **PokerAssistant** Xcode scheme. They exercise card selection, duplicate blocking, live odds/advice, invalid input, relaunch persistence, setup, undo, practice grading, independent tab state and accessibility text sizes.

## Phase 4: practice

Open **Practice** for unlimited randomized flop drills with two face cards. Each drill shuffles J/Q/K hole cards and draws a three-card flop from the remaining deck, then varies the pot, stacks, amount to call and preflop initiative. Use that context to choose **Bet**, **Check** or **Fold**. Results reveal the engine's recommended sizing, explanation, board texture and SPR. **Next Scenario** generates another drill; the heading simply reads **FLOP**, with no drill counter, ten-hand loop or session limit.

Practice fits on one screen without scrolling. Cards, typography and spacing adapt to the available room; landscape uses two columns. Action buttons retain a minimum 44-point height, and full card and feedback descriptions remain available to VoiceOver.

The score counts each displayed drill once and survives tab switches during the app session. It resets when the app restarts. Practice never replaces the live table's cards, stacks, bankroll or saved session.

Each generated input is evaluated with `PostflopHeuristicEngine` before presentation. Scenario definitions contain no answer table. `Card` provides card identities and `Deck` provides exclusion, shuffle and draw. Opening all-ins count as **Bet**; Call, Raise and all-in call/raise recommendations are excluded from this three-choice mode. Fold drills explicitly show an outstanding bet; selecting Check or Bet there is graded incorrect with a legality explanation. Sizing is taught in feedback, rather than scored as a separate input.

```swift
import SwiftUI
import PokerCore
import PokerUI

@MainActor
struct TrainingScreen: View {
    @State private var practice = PracticeViewModel()

    var body: some View {
        PracticeView(model: practice)
    }
}
```

Use `PracticeViewModel(seed: 16)` to replay a generated session for testing. Normal sessions use system randomness. Inject an array through `PracticeViewModel(scenarios:)` for a curated sequence that cycles explicitly; the original ten drills remain available as fixtures, including K♠ Q♠ on A♥ 8♦ 2♣. Empty, malformed or unsupported fixtures show an unavailable state without awarding points or retaining stale advice. This module tests agreement with the app's simplified postflop heuristics; its grades are not solver-derived GTO judgments or opponent-range equity estimates.

The current native verification target is **iPhone 16 Pro**, in portrait and landscape, including the largest system text setting.

See the [Phase 4 delivery notes](docs/phase-four-delivery.md) for verification results and simulator screenshots.

## Example

This example is mirrored by the unit-test fixtures. All probability APIs return **fractions from 0 to 1**; multiply by 100 or use percent formatting for display.

```swift
import PokerCore

let holeCards = [
    Card(rank: .ace, suit: .hearts),
    Card(rank: .seven, suit: .hearts)
]
let flop = [
    Card(rank: .king, suit: .hearts),
    Card(rank: .two, suit: .hearts),
    Card(rank: .nine, suit: .clubs)
]

let hand = try HandEvaluator.evaluate(holeCards + flop)
print(hand.category.name)  // High Card

let report = try OutsCalculator.calculate(holeCards: holeCards, board: flop)
print(report.count)        // 9
print(report.cards.map(\.description).joined(separator: ", "))
// 3♥, 4♥, 5♥, 6♥, 8♥, 9♥, 10♥, J♥, Q♥

let approximateDrawChance = try PokerMath.ruleOfTwoAndFour(
    outs: report.count, street: report.street
) // Optional(0.36), approximately 36% across turn and river

let nextCardChance = report.nextCardCompletionProbability
// Optional(9.0 / 47.0), approximately 19.15% on the turn alone

let requiredEquity = try PokerMath.requiredEquity(
    potBeforeCall: 150, callAmount: 50
) // 0.25, or 25%
```

The evaluator returns `HandValue`. Compare values directly with `<`, `>`, or `==`; equal values split a pot regardless of suit. A royal flush is an ace-high `.straightFlush`. Hold'em permits the best hand to use zero, one or two hole cards.

## What “outs” means here

`OutsCalculator` counts **potential made-hand outs**: each unseen next card that upgrades the current category into a straight, flush, full house, quads or straight flush. Each physical card appears once and includes its resulting hand value. Straight/flush overlaps and straight-flush completions are therefore not counted twice.

This is an exact enumeration under that definition, **not an exact count of winning outs**. Unknown opponents can have better hands or redraw. It deliberately excludes pair/trips improvements, stronger hands within an already-made category, and backdoor draws that require two specific cards. It cannot provide showdown equity without an opponent model. Zero completion outs does not imply zero chance of winning.

On the turn, a candidate is excluded if the resulting best hand equals the board's full five-card value. A hole card that improves that value still counts, even when the board has the same category. On the river, there are no future outs and draw probability is `nil`.

Optional `deadCards` removes known unavailable cards from both the candidate list and the denominator of the exact next-card probability. Duplicate physical cards across hole, board and dead cards throw an error.

## Math conventions

- **Pot odds:** `callAmount / (potBeforeCall + callAmount)`. The pot input includes the opponent's outstanding bet and excludes the hero's pending call. A zero call needs 0% equity. Negative or nonfinite amounts are rejected.
- **Rule of 4:** `min(1, outs × 4 / 100)` on the flop, assuming the player sees both remaining streets. Facing a bet that buys only the next card requires a different horizon.
- **Rule of 2:** `outs × 2 / 100` on the turn. Neither rule is an exact draw probability; the out set can change on the next street, and dead cards can change the denominator.
- **Preflop/river:** the draw heuristic returns `nil` with zero outs. Impossible out counts are rejected.

These draw estimates must not be presented as “Win %.” The recommendation engine distinguishes made-hand strength and draw probability; it does not calculate equity versus an opponent range.

## Phase 2: preflop chart

`PreflopStrategy.chart` contains **6,084 explicit decisions**: six positions × 169 hands × three stack depths × two situations. Compact hardcoded ranges expand into a dictionary, with deliberate fold defaults and a free check for the unopened big blind.

```swift
let startingHand = try StartingHand(holeCards: [
    Card(rank: .ace, suit: .hearts),
    Card(rank: .five, suit: .hearts)
])
let key = PreflopKey(
    position: .button, hand: startingHand,
    depth: .bb40, situation: .unopened
)
let chartAction = PreflopStrategy.chart[key]
// Optional(.raise(bigBlinds: 2.5))
```

Positions are UTG, HJ, CO, BTN, SB and BB. Depths are 20, 40 and 100 BB; the nearest bucket is used, with shallower ties and endpoint clamping. Charts return fold, check, call, raise-to-2.5-BB or three-bet intents. Three-bets use 3× the opening total outside the blinds and 4× from a blind; the betting model enforces the actual minimum and stack cap.

These are **simplified GTO-inspired presets, not solver-derived GTO ranges**. They cover unopened pots and facing one opening raise. Opener ranges, limpers, re-raised pots, multiple callers, rake and tournament ICM are outside the model. Using an endpoint chart for an extreme stack depth remains an approximation, identified in the recommendation notes.

## Phase 2: postflop decisions

The board analyzer reports dry/rainbow, wet/connected or monotone, plus pairing, suit concentration and straight connectivity. A two-tone disconnected board is classified as wet. Ace-low windows are included; ranks never wrap through king–ace–two.

Rules run in this order:

1. Respect already-all-in players and whether further matched betting is possible.
2. With SPR below 1 and hero-owned top pair or better, commit the effective stack using a legal bet, raise, call or actual hero all-in.
3. When facing a bet, price the call before considering a continuation bet. Hero-owned two pair or better can continue without draw outs. Top pair uses a conservative one-third required-equity threshold outside the short-stack rule. Guaranteed split boards are handled directly.
4. For weak drawing hands, compare pot odds to the applicable completion estimate. A normal flop call buys one card, so use the exact next-card completion probability. If a flop call closes betting, use Rule of 4. On the turn, use exact next-card completion odds for the decision while still displaying Rule of 2.
5. When checked to on a dry flop as preflop aggressor, suggest 33% pot. Otherwise, hero-owned strong made hands may bet 66%; weaker holdings check.

All recommendations include reasons and approximation notes. Board-supplied pairs, trips or quads do not by themselves count as hero-owned value. A checked-to hand is never told to fold. Bet sizes respect the big-blind minimum and stack coverage; if a covered non-all-in minimum wager is impossible, the action falls back to a check or call.

## Phase 2: ViewModel

`PokerViewModel` uses `@MainActor @Observable` and is owned by the SwiftUI session layer. The engine has no network, persistence service or solver dependency.

```swift
@MainActor
func makeExampleModel() throws -> PokerViewModel {
    let model = PokerViewModel(
        bankroll: 5_000,
        betting: BettingState(
            pot: 15, amountToCall: 10,
            heroStack: 400, opponentStack: 390, bigBlind: 10
        ),
        position: .button
    )
    try model.setCard(Card(rank: .ace, suit: .hearts), at: .hole(0))
    try model.setCard(Card(rank: .five, suit: .hearts), at: .hole(1))
    // model.analysis.recommendation?.action == .raise(to: 25)
    // model.analysis.chartDepth == .bb40
    return model
}
```

Card slots are `.hole(0...1)`, `.flop(0...2)`, `.turn` and `.river`. Use `setCard(_:at:)` and `availableCards(for:)`; duplicate cards and out-of-order later streets are rejected without changing the valid state. Partial hole/flop selection clears old recommendations. Clearing a flop card removes turn and river; clearing turn removes river. Setting a new valid input automatically recomputes `analysis`, including after nested edits such as `model.betting.pot = 200`.

`analysis` includes status, readable input errors, street, current hand, texture, individual outs, required equity, both draw-probability horizons, effective stack, SPR, chart depth and the recommended action. Invalid input produces no stale statistics or advice.

`bankroll` records the session balance separately. `heroStack` and `opponentStack` are chips still behind after earlier bets; the maximum additional covered commitment is `min(heroStack, opponentStack + amountToCall)`. A short call removes the uncallable excess of the opposing bet from the pot-odds denominator. The model is heads-up and does not calculate multiway side pots.

Action amounts use chips: `.call`, `.bet` and `.allIn` are additional chips, while `.raise(to:)` is the total street contribution. `heroStreetContribution` and `minimumRaiseIncrement` must reflect the current betting round. `resetHand()` clears cards and betting-round inputs while preserving bankroll, stacks, blind size and position. Recommendations never automatically debit balances or apply bets.

## Verified delivery

The Phase 3 release unit suite passed **117 tests**, including the exhaustive five-card evaluator audit and session/input validation tests. All **three native UI journeys** passed on iPhone 17 Pro. The final accessibility layout is also checked on iPhone SE at the largest Dynamic Type size. Physical-device signing and App Store submission are not part of this local delivery.

See [the delivery report](docs/phase-three-delivery.md), [the recommendation screen](docs/screenshots/iphone-flop-recommendation.png), and [the statistics screen](docs/screenshots/iphone-flop-statistics.png).
