import XCTest
import PokerCore

final class OutsCalculatorTests: XCTestCase {
    func testFlushDrawListsNineSpecificHearts() throws {
        let report = try OutsCalculator.calculate(holeCards: cards("Ah 7h"), board: cards("Kh 2h 9c"))
        XCTAssertEqual(Set(report.cards), Set(cards("3h 4h 5h 6h 8h 9h Th Jh Qh")))
        XCTAssertEqual(report.count, 9)
        XCTAssertEqual(report.unseenCardCount, 47)
        XCTAssertEqual(report.street, .flop)
        XCTAssertEqual(try XCTUnwrap(report.nextCardCompletionProbability), 9.0 / 47, accuracy: 1e-12)
    }

    func testOpenEndedStraightHasEightOuts() throws {
        let report = try OutsCalculator.calculate(holeCards: cards("9c 8d"), board: cards("7h 6s Kc"))
        XCTAssertEqual(Set(report.cards), Set(cards("5s 5h 5d 5c Ts Th Td Tc")))
    }

    func testGutshotAndWheelDrawsHaveFourOuts() throws {
        let broadway = try OutsCalculator.calculate(holeCards: cards("Ac Kd"), board: cards("Qh Js 2c"))
        XCTAssertEqual(Set(broadway.cards), Set(cards("Ts Th Td Tc")))
        let wheel = try OutsCalculator.calculate(holeCards: cards("Ac 2d"), board: cards("3h 4s Kc"))
        XCTAssertEqual(Set(wheel.cards), Set(cards("5s 5h 5d 5c")))
    }

    func testOpenEndedStraightFlushDrawDoesNotDoubleCountSharedOuts() throws {
        let report = try OutsCalculator.calculate(holeCards: cards("9h 8h"), board: cards("7h 6c 2h"))
        // Nine hearts + eight straight cards, minus the two shared hearts.
        XCTAssertEqual(report.count, 15)
        XCTAssertEqual(Set(report.cards).count, 15)
        XCTAssertEqual(Set(report.cards), Set(cards("Ah Kh Qh Jh Th 6h 5h 4h 3h Ts Td Tc 5s 5d 5c")))
    }

    func testStraightFlushOutGetsItsActualResultingCategory() throws {
        let report = try OutsCalculator.calculate(holeCards: cards("Ah Kh"), board: cards("Qh Jh 2c"))
        XCTAssertEqual(report.count, 12)
        XCTAssertEqual(report.outs.filter { $0.resultingHand.category == .straight }.count, 3)
        XCTAssertEqual(report.outs.filter { $0.resultingHand.category == .flush }.count, 8)
        XCTAssertEqual(report.outs.filter { $0.resultingHand.category == .straightFlush }.map(\.card), cards("Th"))
    }

    func testSetHasSevenFlopAndTenTurnFullHouseOrQuadsOuts() throws {
        let flop = try OutsCalculator.calculate(holeCards: cards("Ac Ad"), board: cards("Ah Kc 2d"))
        XCTAssertEqual(Set(flop.cards), Set(cards("As Ks Kh Kd 2s 2h 2c")))
        let turn = try OutsCalculator.calculate(holeCards: cards("Ac Ad"), board: cards("Ah Kc 2d 9s"))
        XCTAssertEqual(turn.count, 10)
        XCTAssertEqual(turn.street, .turn)
        XCTAssertEqual(turn.unseenCardCount, 46)
        XCTAssertEqual(try XCTUnwrap(turn.nextCardCompletionProbability), 10.0 / 46, accuracy: 1e-12)
    }

    func testTwoPairHasFourFullHouseOuts() throws {
        let report = try OutsCalculator.calculate(holeCards: cards("Ac Kd"), board: cards("Ah Ks 2d"))
        XCTAssertEqual(Set(report.cards), Set(cards("Ad As Kc Kh")))
    }

    func testAFullHouseOnlyCountsQuadsAsANewCategory() throws {
        let report = try OutsCalculator.calculate(holeCards: cards("Ac Ad"), board: cards("Ah Kc Kd"))
        XCTAssertEqual(report.cards, cards("As"))
    }

    func testBoardOnlyStraightDoesNotCountAsAnOut() throws {
        let report = try OutsCalculator.calculate(holeCards: cards("2c 3d"), board: cards("9h Ts Jc Qd"))
        XCTAssertEqual(report.count, 0)
    }

    func testHoleCardCanImproveTheStraightAlsoMadeOnTheBoard() throws {
        let report = try OutsCalculator.calculate(holeCards: cards("Kh 2d"), board: cards("8h 9s Tc Jd"))
        XCTAssertEqual(Set(report.cards), Set(cards("Qh Qs Qc Qd")))
    }

    func testBoardFullHouseWithBetterHolePairStillCounts() throws {
        let report = try OutsCalculator.calculate(holeCards: cards("Ac Ad"), board: cards("Kh Kd 2c 2d"))
        XCTAssertEqual(Set(report.cards), Set(cards("Ah As Kc Ks 2h 2s")))
    }

    func testKnownDeadCardsReduceOutsAndUnseenDeck() throws {
        let report = try OutsCalculator.calculate(
            holeCards: cards("Ah 7h"), board: cards("Kh 2h 9c"), deadCards: cards("Qh Jh")
        )
        XCTAssertEqual(report.count, 7)
        XCTAssertEqual(report.unseenCardCount, 45)
        XCTAssertFalse(report.cards.contains(cards("Qh")[0]))
    }

    func testRiverHasNoFutureOutsOrDrawProbability() throws {
        let report = try OutsCalculator.calculate(holeCards: cards("Ah 7h"), board: cards("Kh 2h 9c 3h Qs"))
        XCTAssertEqual(report.street, .river)
        XCTAssertEqual(report.currentHand.category, .flush)
        XCTAssertEqual(report.count, 0)
        XCTAssertNil(report.nextCardCompletionProbability)
    }

    func testBackdoorFlushAndOvercardsAreNotImmediateMadeHandOuts() throws {
        let report = try OutsCalculator.calculate(holeCards: cards("Ah Kh"), board: cards("9h 4c 2d"))
        XCTAssertEqual(report.count, 0)
    }

    func testRejectsInvalidHoleBoardAndOverlappingCards() {
        XCTAssertThrowsError(try OutsCalculator.calculate(holeCards: cards("Ah"), board: cards("Kh 2h 9c")))
        XCTAssertThrowsError(try OutsCalculator.calculate(holeCards: cards("Ah 7h"), board: cards("Kh 2h")))
        XCTAssertThrowsError(try OutsCalculator.calculate(holeCards: cards("Ah 7h"), board: cards("Kh 2h 9c 3s 4s 5s")))
        XCTAssertThrowsError(try OutsCalculator.calculate(holeCards: cards("Ah Ah"), board: cards("Kh 2h 9c")))
        XCTAssertThrowsError(try OutsCalculator.calculate(holeCards: cards("Ah 7h"), board: cards("Ah 2h 9c")))
        XCTAssertThrowsError(try OutsCalculator.calculate(holeCards: cards("Ah 7h"), board: cards("Kh 2h 9c"), deadCards: cards("Ah")))
        XCTAssertThrowsError(try OutsCalculator.calculate(holeCards: cards("Ah 7h"), board: cards("Kh 2h 9c"), deadCards: cards("Qs Qs")))
    }
}
