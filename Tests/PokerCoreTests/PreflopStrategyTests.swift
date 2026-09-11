import XCTest
import PokerCore

final class PreflopStrategyTests: XCTestCase {
    func testPositionNamesUseCommonSixMaxLabels() {
        XCTAssertEqual(Position.underTheGun.name, "UTG")
        XCTAssertEqual(Position.hijack.name, "HJ")
        XCTAssertEqual(Position.cutoff.name, "CO")
        XCTAssertEqual(Position.button.name, "BTN")
        XCTAssertEqual(Position.smallBlind.name, "SB")
        XCTAssertEqual(Position.bigBlind.name, "BB")
    }

    func testStartingHandCanonicalizesOrderPairsAndSuiting() throws {
        XCTAssertEqual(try StartingHand(holeCards: cards("As Ah")).notation, "AA")
        XCTAssertEqual(try StartingHand(holeCards: cards("Ks Ac")).notation, "AKo")
        XCTAssertEqual(try StartingHand(holeCards: cards("Ks As")).notation, "AKs")
        XCTAssertEqual(try StartingHand(holeCards: cards("9h Th")).notation, "T9s")
        XCTAssertEqual(try StartingHand(holeCards: cards("9h Tc")).notation, "T9o")
        XCTAssertEqual(
            try StartingHand(holeCards: cards("2c Ad")),
            try StartingHand(holeCards: cards("Ad 2c"))
        )
    }

    func testStartingHandRejectsWrongCountAndDuplicateCard() {
        for fixture in ["", "As", "As Kh Qd"] {
            XCTAssertThrowsError(try StartingHand(holeCards: cards(fixture))) {
                XCTAssertEqual(
                    $0 as? PokerInputError,
                    .invalidCardCount(actual: cards(fixture).count, expected: "exactly 2 hole cards")
                )
            }
        }
        XCTAssertThrowsError(try StartingHand(holeCards: cards("As As"))) {
            XCTAssertEqual($0 as? PokerInputError, .duplicateCard(cards("As")[0]))
        }
    }

    func testAllStartingHandsContainExactly169CanonicalClasses() {
        XCTAssertEqual(StartingHand.all.count, 169)
        XCTAssertEqual(Set(StartingHand.all).count, 169)
        XCTAssertEqual(Set(StartingHand.all.map(\.notation)).count, 169)
        XCTAssertTrue(StartingHand.all.contains { $0.notation == "AA" })
        XCTAssertTrue(StartingHand.all.contains { $0.notation == "AKs" })
        XCTAssertTrue(StartingHand.all.contains { $0.notation == "AKo" })
        XCTAssertTrue(StartingHand.all.contains { $0.notation == "T9s" })
        XCTAssertFalse(StartingHand.all.contains { $0.notation.contains("10") })
    }

    func testAllPhysicalStartingHandsMapToThe169Classes() throws {
        var classCounts: [StartingHand: Int] = [:]
        let deck = Deck.allCards
        for first in 0..<(deck.count - 1) {
            for second in (first + 1)..<deck.count {
                classCounts[try StartingHand(holeCards: [deck[first], deck[second]]), default: 0] += 1
            }
        }

        XCTAssertEqual(classCounts.values.reduce(0, +), 1_326)
        XCTAssertEqual(classCounts.count, 169)
        XCTAssertEqual(classCounts.values.filter { $0 == 6 }.count, 13)
        XCTAssertEqual(classCounts.values.filter { $0 == 4 }.count, 78)
        XCTAssertEqual(classCounts.values.filter { $0 == 12 }.count, 78)
    }

    func testStackDepthUsesNearestBucketWithShallowerTiesAndEndpoints() throws {
        XCTAssertEqual(try StackDepth.nearest(to: 0.1), .bb20)
        XCTAssertEqual(try StackDepth.nearest(to: 20), .bb20)
        XCTAssertEqual(try StackDepth.nearest(to: 30), .bb20)
        XCTAssertEqual(try StackDepth.nearest(to: 30.01), .bb40)
        XCTAssertEqual(try StackDepth.nearest(to: 70), .bb40)
        XCTAssertEqual(try StackDepth.nearest(to: 70.01), .bb100)
        XCTAssertEqual(try StackDepth.nearest(to: 500), .bb100)
        XCTAssertEqual(try StackDepth.nearest(to: .greatestFiniteMagnitude), .bb100)
    }

    func testStackDepthRejectsNonpositiveAndNonfiniteValues() {
        for value in [0.0, -1.0, .infinity, -.infinity, .nan] {
            XCTAssertThrowsError(try StackDepth.nearest(to: value)) {
                XCTAssertEqual($0 as? PokerInputError, .invalidChipAmount)
            }
        }
    }

    func testChartContainsEveryPositionHandDepthAndSituationKey() {
        XCTAssertEqual(PreflopStrategy.chart.count, 6_084)
        for position in Position.allCases {
            for hand in StartingHand.all {
                for depth in StackDepth.allCases {
                    for situation in PreflopSituation.allCases {
                        let key = PreflopKey(
                            position: position,
                            hand: hand,
                            depth: depth,
                            situation: situation
                        )
                        XCTAssertNotNil(PreflopStrategy.chart[key], "Missing \(position.name) \(hand.notation) \(depth.rawValue) \(situation.rawValue)")
                    }
                }
            }
        }
    }

    func testButtonA5sAt40BigBlindsRaisesTwoPointFive() throws {
        XCTAssertEqual(
            PreflopStrategy.action(
                position: .button,
                hand: try StartingHand(holeCards: cards("As 5s")),
                depth: .bb40,
                situation: .unopened
            ),
            .raise(bigBlinds: 2.5)
        )
    }

    func testLatePositionOpensMarginalHandsThatEarlyPositionFolds() throws {
        let tenNineSuited = try StartingHand(holeCards: cards("Th 9h"))
        let aceTenOffsuit = try StartingHand(holeCards: cards("Ac Td"))

        XCTAssertEqual(PreflopStrategy.action(position: .underTheGun, hand: tenNineSuited, depth: .bb40, situation: .unopened), .fold)
        XCTAssertEqual(PreflopStrategy.action(position: .button, hand: tenNineSuited, depth: .bb40, situation: .unopened), .raise(bigBlinds: 2.5))
        XCTAssertEqual(PreflopStrategy.action(position: .underTheGun, hand: aceTenOffsuit, depth: .bb100, situation: .unopened), .fold)
        XCTAssertEqual(PreflopStrategy.action(position: .cutoff, hand: aceTenOffsuit, depth: .bb100, situation: .unopened), .raise(bigBlinds: 2.5))
    }

    func testDepthChangesMarginalOpeningAndDefenseDecisions() throws {
        let pocketFives = try StartingHand(holeCards: cards("5c 5d"))
        let aceJackOffsuit = try StartingHand(holeCards: cards("Ah Jc"))

        XCTAssertEqual(PreflopStrategy.action(position: .cutoff, hand: pocketFives, depth: .bb20, situation: .unopened), .fold)
        XCTAssertEqual(PreflopStrategy.action(position: .cutoff, hand: pocketFives, depth: .bb40, situation: .unopened), .raise(bigBlinds: 2.5))
        XCTAssertEqual(PreflopStrategy.action(position: .button, hand: aceJackOffsuit, depth: .bb20, situation: .facingOpenRaise), .threeBet(multiplier: 3))
        XCTAssertEqual(PreflopStrategy.action(position: .button, hand: aceJackOffsuit, depth: .bb100, situation: .facingOpenRaise), .call)
    }

    func testPremiumPairsOpenAndThreeBetAtAllDepths() throws {
        let premiums = [
            try StartingHand(holeCards: cards("As Ah")),
            try StartingHand(holeCards: cards("Ks Kh"))
        ]
        for hand in premiums {
            for depth in StackDepth.allCases {
                for position in Position.allCases where position != .bigBlind {
                    XCTAssertEqual(
                        PreflopStrategy.action(position: position, hand: hand, depth: depth, situation: .unopened),
                        .raise(bigBlinds: 2.5)
                    )
                }
                for position in Position.allCases {
                    let multiplier = position == .smallBlind || position == .bigBlind ? 4.0 : 3.0
                    XCTAssertEqual(
                        PreflopStrategy.action(position: position, hand: hand, depth: depth, situation: .facingOpenRaise),
                        .threeBet(multiplier: multiplier)
                    )
                }
            }
        }
    }

    func testFacingOpenRangesIncludeCallsAndPositionBasedThreeBetSizing() throws {
        let kingQueenSuited = try StartingHand(holeCards: cards("Kh Qh"))
        let aceKingOffsuit = try StartingHand(holeCards: cards("Ac Kd"))

        XCTAssertEqual(PreflopStrategy.action(position: .button, hand: kingQueenSuited, depth: .bb40, situation: .facingOpenRaise), .call)
        XCTAssertEqual(PreflopStrategy.action(position: .bigBlind, hand: kingQueenSuited, depth: .bb40, situation: .facingOpenRaise), .call)
        XCTAssertEqual(PreflopStrategy.action(position: .cutoff, hand: aceKingOffsuit, depth: .bb40, situation: .facingOpenRaise), .threeBet(multiplier: 3))
        XCTAssertEqual(PreflopStrategy.action(position: .smallBlind, hand: aceKingOffsuit, depth: .bb40, situation: .facingOpenRaise), .threeBet(multiplier: 4))
    }

    func testUnopenedBigBlindAlwaysChecks() throws {
        for depth in StackDepth.allCases {
            for fixture in ["As Ah", "7c 2d", "Jh Th"] {
                XCTAssertEqual(
                    PreflopStrategy.action(
                        position: .bigBlind,
                        hand: try StartingHand(holeCards: cards(fixture)),
                        depth: depth,
                        situation: .unopened
                    ),
                    .check
                )
            }
        }
    }

    func testHandsOutsideExplicitRangesFold() throws {
        let sevenTwoOffsuit = try StartingHand(holeCards: cards("7c 2d"))
        XCTAssertEqual(PreflopStrategy.action(position: .button, hand: sevenTwoOffsuit, depth: .bb100, situation: .unopened), .fold)
        XCTAssertEqual(PreflopStrategy.action(position: .bigBlind, hand: sevenTwoOffsuit, depth: .bb20, situation: .facingOpenRaise), .fold)
    }
}
