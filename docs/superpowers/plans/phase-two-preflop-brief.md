# Preflop task requirements

Implement only `Sources/PokerCore/PreflopStrategy.swift` and `Tests/PokerCoreTests/PreflopStrategyTests.swift`. Existing core models are in Sources/PokerCore and a fixture helper `cards(_:)` exists in Tests. Write tests first and establish failures before production implementation. Do not change Package.swift or other source files. No git commits (workspace has no Git repository). Do not spawn additional agents.

Public API contracts:

```swift
public enum Position: String, CaseIterable, Sendable { case underTheGun, hijack, cutoff, button, smallBlind, bigBlind }
// Include public var name: String.
public enum StackDepth: Int, CaseIterable, Sendable { case bb20 = 20, bb40 = 40, bb100 = 100 }
// Include public static func nearest(to bigBlinds: Double) throws -> StackDepth.
// Positive finite only; nearest absolute distance; ties shallower; outside buckets uses nearest endpoint.
public enum PreflopSituation: String, CaseIterable, Sendable { case unopened, facingOpenRaise }
public struct StartingHand: Hashable, Sendable {
  public init(holeCards: [Card]) throws
  public var notation: String { get } // AA, AKs, AKo, T9s; never 10 or reversed rank order
  public static let all: [StartingHand] // exactly 169 canonical hands
}
public enum PreflopChartAction: Equatable, Sendable {
  case fold, check, call
  case raise(bigBlinds: Double)
  case threeBet(multiplier: Double)
}
public struct PreflopKey: Hashable, Sendable {
  public let position: Position
  public let hand: StartingHand
  public let depth: StackDepth
  public let situation: PreflopSituation
  public init(position: Position, hand: StartingHand, depth: StackDepth, situation: PreflopSituation)
}
public enum PreflopStrategy {
  public static let chart: [PreflopKey: PreflopChartAction]
  public static func action(position: Position, hand: StartingHand, depth: StackDepth, situation: PreflopSituation) -> PreflopChartAction
}
```

Requirements: Dictionary complete across 6*169*3*2=6084 keys. Explicit hardcoded range presets for each depth/position/situation, using compact string lists expanded into dictionaries if useful; unspecified hands deliberately fold, and an unopened BB always checks (walk/free option). Opening selected hands raise 2.5BB. BTN A5s at40BB raises2.5. Premium AA/KK must open from non-BB positions and three-bet facing a raise. Facing-open defense must have meaningful call and 3bet ranges by position/depth, not random scoring; use3x non-blind and4x blind 3bet intents. Depth should change some marginal decisions. Label in comments as GTO-inspired simplified six-seat presets, not actual solver charts, and note opener position/range and multiway/limped/re-raised pots are not modeled. No external services or fetched charts.

Tests: all169 classes cover1326 physical combinations; classification canonicalizes reverse order, pocketpairs, suited/offsuit, ten notation; duplicates/wrong count rejected; full6084-key coverage; provided BTN example; early vs late marginal ranges; depth change examples; premium3bets; call examples; BB free checks; depth mapping tie/invalid boundaries. Use XCTest literal expectations, not values derived from the implementation.

Run Swift tests with caches in /private/tmp, but a separate scratch directory `/private/tmp/pokerapp-preflop-build` to avoid concurrent SPM locks. Useful command prefix: `CLANG_MODULE_CACHE_PATH=/private/tmp/pokerapp-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/pokerapp-module-cache swift test --scratch-path /private/tmp/pokerapp-preflop-build --cache-path /private/tmp/pokerapp-swift-cache --config-path /private/tmp/pokerapp-swift-config --security-path /private/tmp/pokerapp-swift-security --disable-sandbox --filter PreflopStrategyTests`.

Write a report at `docs/superpowers/plans/phase-two-preflop-report.md` with files, test evidence, decisions and concerns. Return a concise completion message.
