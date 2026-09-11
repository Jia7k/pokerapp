import XCTest
import PokerCore

final class HandEvaluatorTests: XCTestCase {
    func testEveryCategoryAndItsCompleteTiebreakVector() throws {
        let fixtures: [(String, HandCategory, [Rank])] = [
            ("As Jd 9h 5c 3s", .highCard, [.ace, .jack, .nine, .five, .three]),
            ("As Ad Jh 9c 3s", .onePair, [.ace, .jack, .nine, .three]),
            ("As Ad Jh Jc 3s", .twoPair, [.ace, .jack, .three]),
            ("As Ad Ah Jc 3s", .threeOfAKind, [.ace, .jack, .three]),
            ("9s Td Jh Qc Ks", .straight, [.king]),
            ("As Js 9s 5s 3s", .flush, [.ace, .jack, .nine, .five, .three]),
            ("As Ad Ah Jc Js", .fullHouse, [.ace, .jack]),
            ("As Ad Ah Ac Js", .fourOfAKind, [.ace, .jack]),
            ("Ts Js Qs Ks As", .straightFlush, [.ace])
        ]
        var previous: HandValue?
        for (notation, category, tiebreakers) in fixtures {
            let value = try HandEvaluator.evaluate(cards(notation))
            XCTAssertEqual(value.category, category, notation)
            XCTAssertEqual(value.tiebreakers, tiebreakers, notation)
            if let previous { XCTAssertGreaterThan(value, previous) }
            previous = value
        }
    }

    func testWheelIsFiveHighAndLosesToSixHigh() throws {
        let wheel = try HandEvaluator.evaluate(cards("As 2d 3h 4c 5s Kh Qd"))
        let sixHigh = try HandEvaluator.evaluate(cards("2s 3d 4h 5c 6s Kd Qh"))
        XCTAssertEqual(wheel.category, .straight)
        XCTAssertEqual(wheel.tiebreakers, [.five])
        XCTAssertGreaterThan(sixHigh, wheel)
        let suitedWheel = try HandEvaluator.evaluate(cards("As 2s 3s 4s 5s"))
        XCTAssertEqual(suitedWheel.category, .straightFlush)
        XCTAssertEqual(suitedWheel.tiebreakers, [.five])
    }

    func testAceCannotWrapAroundAHighStraight() throws {
        let value = try HandEvaluator.evaluate(cards("Qs Kd Ah 2c 3s"))
        XCTAssertEqual(value.category, .highCard)
    }

    func testDoubleTripsChooseHigherTripsForFullHouse() throws {
        let value = try HandEvaluator.evaluate(cards("Ks Kh Kd Qs Qh Qd 2c"))
        XCTAssertEqual(value.category, .fullHouse)
        XCTAssertEqual(value.tiebreakers, [.king, .queen])
    }

    func testThreePairsChooseTopTwoAndBestRemainingKicker() throws {
        let value = try HandEvaluator.evaluate(cards("As Ah Ks Kh Qs Qh 2c"))
        XCTAssertEqual(value.category, .twoPair)
        XCTAssertEqual(value.tiebreakers, [.ace, .king, .queen])
    }

    func testSixAndSevenCardsSelectBestFiveRegardlessOfInputOrder() throws {
        let six = cards("As Js 9s 5s 3s Ks")
        XCTAssertEqual(try HandEvaluator.evaluate(six).tiebreakers, [.ace, .king, .jack, .nine, .five])
        let seven = six + cards("2h")
        XCTAssertEqual(try HandEvaluator.evaluate(seven), try HandEvaluator.evaluate(seven.reversed()))
    }

    func testFlushAndStraightInDifferentSuitsDoNotMakeStraightFlush() throws {
        let value = try HandEvaluator.evaluate(cards("2h 4h 6h 8h Th 7s 9d"))
        XCTAssertEqual(value.category, .flush)
        XCTAssertEqual(value.tiebreakers, [.ten, .eight, .six, .four, .two])
    }

    func testSuitsDoNotBreakTiesAndBoardCanPlay() throws {
        XCTAssertEqual(
            try HandEvaluator.evaluate(cards("As Kd Qh Jc Ts")),
            try HandEvaluator.evaluate(cards("Ah Kc Qs Jd Th"))
        )
        let board = cards("As Ks Qs Js Ts")
        XCTAssertEqual(try HandEvaluator.evaluate(board), try HandEvaluator.evaluate(board + cards("2h 3d")))
    }

    func testAllKickersParticipateInComparison() throws {
        let pairs = [
            ("As Ad Kh Qc Js", "Ah Ac Ks Qd Ts"),
            ("As Ks 9s 5s 4s", "Ah Kh 9h 5h 3h"),
            ("As Ad Kh Kc Qs", "Ah Ac Ks Kd Js"),
            ("9s 9d 9h 9c As", "Ts Td Th Tc 2s"),
            ("Ks Kd Kh 2c 2s", "Qs Qd Qh Ac As")
        ]
        for (index, pair) in pairs.enumerated() {
            let first = try HandEvaluator.evaluate(cards(pair.0))
            let second = try HandEvaluator.evaluate(cards(pair.1))
            if index == 3 { XCTAssertLessThan(first, second) }
            else { XCTAssertGreaterThan(first, second) }
        }
    }

    func testRejectsDuplicateCardsAndInvalidCardCounts() {
        XCTAssertThrowsError(try HandEvaluator.evaluate(cards("As As Kh Qd Jc")))
        for notation in ["", "As Kh Qd Jc", "As Kh Qd Jc Ts 9h 8d 7c"] {
            XCTAssertThrowsError(try HandEvaluator.evaluate(cards(notation)))
        }
    }
}
