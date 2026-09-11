# iOS project and UI test task

Own only `project.yml`, generated `PokerAssistant.xcodeproj`, `App/PokerAssistantApp.swift`, `App/Assets.xcassets/Contents.json`, `App/Assets.xcassets/AppIcon.appiconset/Contents.json`, and `UITests/PokerAssistantUITests.swift`. Do not edit Package.swift, core/UI library files, README or other agents' files. Root owns actual icon PNG generation. No subagents. Read Phase 3 design spec.

XcodeGen is installed at /opt/homebrew/bin/xcodegen version2.46. Xcode26.6 and iOS26.5 simulator runtime are installed. Root handles simulator commands/build/test execution; do not start simulators or run UI tests yourself.

Create reproducible XcodeGen app project/scheme `PokerAssistant`, iOS17 minimum, Swift6, display name Riverline, bundle identifier `com.riverline.pokerassistant`, iPhone+iPad, portrait/landscape, generated Info.plist, dark appearance, no network permissions or external resources. A LOCAL package at `.` called PokerAssistant exposes PokerCore and PokerUI; app depends on PokerUI (and PokerCore if needed). No remote package resolution. App assets use AppIcon, root will write `App/Assets.xcassets/AppIcon.appiconset/AppIcon.png`1024x1024. Generate standard universal iOS app icon asset metadata. Signing automatic for future physical device with team left unspecified; simulator build can use CODE_SIGNING_ALLOWED=NO. Include shared scheme with UI-test bundle target PokerAssistantUITests.

App entry owns `@State private var session: PokerSession` imported from PokerUI. Root supplies `@MainActor public final class PokerSession { public init(defaults: UserDefaults = .standard) }` and `@MainActor public struct PokerDashboardView: View { public init(session: PokerSession) }`. Instantiate session in @MainActor app init. `.preferredColorScheme(.dark)` window scene. For `--ui-testing`, use a dedicated UserDefaults suite `com.riverline.pokerassistant.uitests`; when `--reset-state` is present clear only this suite. App normal session must never be erased by test mode. Do not seed demo/fake cards into the normal app.

UI tests should verify real app behavior with stable accessibility identifiers. Actual root/component API contracts:
- Header buttons `table.setup`, `hand.new`; undo button `hand.undo`; main scroll `dashboard.scroll`.
- Card buttons `card.hole.0`, `card.hole.1`, `card.flop.0`, `card.flop.1`, `card.flop.2`, `card.turn`, `card.river`.
- Selector suit buttons `selector.suit.spades`, `.hearts`, `.diamonds`, `.clubs`; rank buttons `selector.rank.14` through `.2`; active slot text `selector.activeSlot`; sheet dismissal `selector.done`.
- Card picks auto-advance within hole/flop street and dismiss when that street is complete. Other used cards disabled.
- Pot/call TextFields `input.pot`, `input.call`; keyboard Done `keyboard.done`.
- Action title Text `action.title` (FOLD, CALL, BET33%/BET, RAISE TO, CHECK, ALL IN, ADD YOUR CARDS, CHECK INPUT, WAIT FOR BOARD); amount Text `action.amount`.
- Numeric Text IDs `stats.potOdds`, `stats.drawChance`, `stats.outs`, `stats.spr`.
- Setup fields `setup.bankroll`, `setup.heroStack`, `setup.opponentStack`, `setup.bigBlind`, `setup.contribution`, `setup.minRaise`; Save `setup.save`, Cancel `setup.cancel`. Root provides a native Form in a NavigationStack sheet.
- Strategy aggressor switch `strategy.aggressor`.

Cover 3 focused end-to-end cases:
1. Select Ah7h, verify selecting already-used Ah in second slot is disabled, then enter flop Kh2h9c. Edit pot150/call50. Assert FOLD, 9outs, 36% approximate draw, 25% pot odds. Clearing pot text must show CHECK INPUT without old advice; restore150. Attach screenshot of valid flop.
2. Create a selected hand, terminate/relaunch without reset flag, assert it restores. New hand removes selections; Undo restores them. Edit/save bankroll in setup and confirm through reopening. No network required.
3. Launch with accessibility Dynamic Type `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`, verify card selector/Done/setup remain reachable with scrolling. Capture a screenshot. Keep assertions meaningful, not brittle about exact point sizes.

Use test helper to scroll a field into view, clear a TextField through keyboard delete characters, and tap ranks/suits by ID. Set AppleLanguages(en) and AppleLocale en_US for deterministic numeric assertions. Screenshot attachments lifetime keepAlways. No sleeps as primary synchronization; waitForExistence/hittability and XCTest predicates. Keep test execution serial. Root will run on iPhone17Pro and a compact device, inspecting attachments and fixing integration details if IDs or layout need adjustment.

Generate xcodeproj once App and asset directories exist (source paths may be mostly empty initially). Write report `docs/superpowers/plans/phase-three-project-report.md` with files, generation command, scheme and concerns. Report completion without claiming build/UI success until root runs them.
