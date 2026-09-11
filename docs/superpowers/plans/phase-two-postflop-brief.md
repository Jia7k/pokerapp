# Postflop task requirements

Implement only `Sources/PokerCore/PostflopHeuristicEngine.swift` and `Tests/PokerCoreTests/PostflopHeuristicTests.swift`. Read existing core models and `BettingState.swift` for exact shared interfaces. Root is implementing the stubs in BettingState and MVVM; do not edit those files. The preflop agent owns PreflopStrategy.swift. No git commits; no subagents. Write tests first and establish red before implementing.

Public interfaces to provide:

```swift
public enum BoardTexture: String, Sendable { case dryRainbow, wetConnected, monotone }
public struct BoardTextureReport: Equatable, Sendable {
  public let texture: BoardTexture
  public let isPaired: Bool
  public let maximumSuitCount: Int
  public let isConnected: Bool
}
public enum BoardTextureAnalyzer {
  public static func analyze(_ board: [Card]) throws -> BoardTextureReport
}
public struct MadeHandAssessment: Equatable, Sendable {
  public let value: HandValue
  public let hasTopPairOrBetter: Bool
  public let isStrongMadeHand: Bool // hero-contributed two-pair or better
  public let playsBoard: Bool // river full hand value equals board full value
}
public struct PostflopAnalysis: Equatable, Sendable {
  public let texture: BoardTextureReport
  public let madeHand: MadeHandAssessment
  public let outs: OutsReport
  public let approximateDrawProbability: Double? // Rule of2/4, never true win equity
  public let decisionDrawProbability: Double? // correct horizon for a call
  public let recommendation: ActionRecommendation
}
public enum PostflopHeuristicEngine {
  public static func analyze(holeCards: [Card], board: [Card], betting: BettingState, isPreflopAggressor: Bool) throws -> PostflopAnalysis
}
```

Texture accepts3...5 unique board cards. allsame suit ->monotone; >=2 same suit or >=3 distinct ranks inside ANY legal five-rank straight window ->wetConnected; otherwise dryRainbow. This descriptive simplification marks two-tone disconnected boards as wet. isPaired separate. A23 connected, AK2 not connected (no rank wraparound). Inspect whole current board, with cbet rule only on flop.

Made hand assessment: use HandEvaluator plus hole participation. A pair on board with unmatched hole cards is not top pair. For a one-pair value, pair rank must occur in hole cards; pair>=highest board rank qualifies (including overpair). For two-pair/trips/full-house/quads, require hole participation in the category-forming ranks (not just kicker). For straight/flush/straightflush, exclude playsBoard. Strong made hand means hero-contributed two pair or higher. Full house on board may be improved by a hole pair; compare full ranks. No exact nuts or opponent range model promised.

Decision order and sizing:
1. validate inputs including BettingState; calculate real hand/outs/texture so snapshot stays useful.
2. heroStack0 -> .noAction/.alreadyAllIn.
3. amountToCall0 and opponentStack0 -> .check/.opponentAllIn.
4. SPR<1 AND hasTopPairOrBetter -> betting.commitEffectiveStack(), reason .shortStackValue. Shared sizing correctly downgrades to a call if opponent already all-in or matched raise illegal. Explain actual action, don't claim every effective commitment is a literal hero all-in.
5. If facing a bet, handle before any cbet. Hero-contributed strong made hand -> passiveAction with .madeHandValue (do not fold due0outs). Top pair -> call when requiredEquity<=1/3, otherwise fold (transparent heuristic). Weak hands: compare decisionDrawProbability against requiredEquity, call only with positive probability sufficient; otherwise fold. Use .drawPriceAcceptable/.drawTooExpensive. On ordinary flop calls decisionDrawProbability is exact nextCardCompletionProbability; if closesBettingByCalling use Ruleof4. Turn decisions use exact next-card completion probability; display remains Ruleof2 (final integration correction). River nil, but top-pair/strong-made rules still apply. Do not treat a board-only made hand as hero strength.
6. Checked-to dryRainbow flop and isPreflopAggressor -> sizedBet(potFraction:0.33), .dryBoardContinuationBet. This may be a heuristic bluff.
7. Otherwise strong made hand -> sizedBet(potFraction:0.66), .madeHandValue; else .check/.checkWithoutValue or .boardOnlyHand as relevant.

Use short explanations and notes describing heuristic assumptions. No guarantee of win equity. Don't show "FOLD" when checking is free. Respect action sizing returned by BettingState helpers; do not duplicate chip arithmetic.

Tests should cover specified K♠8♦2♣ dry, J♥T♥9♠ wet, monotone; paired and ace windows; lowSPR KQ onK82 all-in; boardpair/trips/quads false positive traps;25% odds vs4outs=16% all-in-flop fold;9outs ordinaryflop next-card probability<25% fold despite Rule4=.36;same9outs when opponentallin call; facingbet mustnever cbet; river madehand0outs call; checked-to dryaggressor33%; wetweak check;legalminimum/stackcaps through helpers; duplicates and count errors.

Use separate scratch `/private/tmp/pokerapp-postflop-build` and filter PostflopHeuristicTests to avoid SPM lock with other agents. Prefix: `CLANG_MODULE_CACHE_PATH=/private/tmp/pokerapp-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/pokerapp-module-cache swift test --scratch-path /private/tmp/pokerapp-postflop-build --cache-path /private/tmp/pokerapp-swift-cache --config-path /private/tmp/pokerapp-swift-config --security-path /private/tmp/pokerapp-swift-security --disable-sandbox --filter PostflopHeuristicTests`.

Write `docs/superpowers/plans/phase-two-postflop-report.md` with decisions, test results and concerns. Return a concise completion message. Root may still be finishing shared BettingState methods when you first run tests; communicate such dependencies rather than modifying them.
