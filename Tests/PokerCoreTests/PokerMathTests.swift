import XCTest
import PokerCore

final class PokerMathTests: XCTestCase {
    func testPotOddsIncludeTheCallOnce() throws {
        XCTAssertEqual(try PokerMath.requiredEquity(potBeforeCall: 150, callAmount: 50), 0.25)
        XCTAssertEqual(try PokerMath.requiredEquity(potBeforeCall: 100, callAmount: 50), 1.0 / 3, accuracy: 1e-12)
        XCTAssertEqual(try PokerMath.requiredEquity(potBeforeCall: 0, callAmount: 50), 1)
    }

    func testFreeCheckRequiresZeroEquityEvenWithEmptyPot() throws {
        XCTAssertEqual(try PokerMath.requiredEquity(potBeforeCall: 100, callAmount: 0), 0)
        XCTAssertEqual(try PokerMath.requiredEquity(potBeforeCall: 0, callAmount: 0), 0)
    }

    func testPotOddsRejectNegativeAndNonfiniteAmounts() {
        for invalid in [-1.0, .infinity, -.infinity, .nan] {
            XCTAssertThrowsError(try PokerMath.requiredEquity(potBeforeCall: invalid, callAmount: 5))
            XCTAssertThrowsError(try PokerMath.requiredEquity(potBeforeCall: 5, callAmount: invalid))
        }
    }

    func testFiniteLargeChipAmountsDoNotOverflowIntoZeroOdds() throws {
        XCTAssertEqual(try PokerMath.requiredEquity(
            potBeforeCall: .greatestFiniteMagnitude, callAmount: .greatestFiniteMagnitude
        ), 0.5)
    }

    func testRuleOfFourAndTwoReturnFractions() throws {
        XCTAssertEqual(try PokerMath.ruleOfTwoAndFour(outs: 9, street: .flop), 0.36)
        XCTAssertEqual(try PokerMath.ruleOfTwoAndFour(outs: 9, street: .turn), 0.18)
        XCTAssertEqual(try PokerMath.ruleOfTwoAndFour(outs: 4, street: .flop), 0.16)
        XCTAssertEqual(try PokerMath.ruleOfTwoAndFour(outs: 0, street: .flop), 0)
        XCTAssertEqual(try PokerMath.ruleOfTwoAndFour(outs: 30, street: .flop), 1)
    }

    func testRuleIsUnavailableBeforeFlopAndAfterRiver() throws {
        XCTAssertNil(try PokerMath.ruleOfTwoAndFour(outs: 0, street: .preflop))
        XCTAssertNil(try PokerMath.ruleOfTwoAndFour(outs: 0, street: .river))
    }

    func testImpossibleOutCountsAreRejected() {
        XCTAssertThrowsError(try PokerMath.ruleOfTwoAndFour(outs: -1, street: .flop))
        XCTAssertThrowsError(try PokerMath.ruleOfTwoAndFour(outs: 48, street: .flop))
        XCTAssertThrowsError(try PokerMath.ruleOfTwoAndFour(outs: 47, street: .turn))
        XCTAssertThrowsError(try PokerMath.ruleOfTwoAndFour(outs: 1, street: .river))
    }
}
