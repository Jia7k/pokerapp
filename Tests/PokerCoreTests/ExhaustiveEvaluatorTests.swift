import XCTest
import PokerCore

final class ExhaustiveEvaluatorTests: XCTestCase {
    func testAllFiveCardHandsHaveCorrectCategoryAndDistinctValueTotals() throws {
        guard ProcessInfo.processInfo.environment["POKER_EXHAUSTIVE_TESTS"] == "1" else {
            throw XCTSkip("Opt in with POKER_EXHAUSTIVE_TESTS=1 swift test -c release")
        }
        let deck = Deck.allCards
        var totals = [Int](repeating: 0, count: 9)
        var values = [Set<HandValue>](repeating: [], count: 9)
        for a in 0..<48 {
            for b in (a + 1)..<49 {
                for c in (b + 1)..<50 {
                    for d in (c + 1)..<51 {
                        for e in (d + 1)..<52 {
                            let value = try HandEvaluator.evaluate([deck[a], deck[b], deck[c], deck[d], deck[e]])
                            totals[value.category.rawValue] += 1
                            values[value.category.rawValue].insert(value)
                        }
                    }
                }
            }
        }
        // Independent combinatorial totals, in ascending category order.
        XCTAssertEqual(totals, [1_302_540, 1_098_240, 123_552, 54_912, 10_200, 5_108, 3_744, 624, 40])
        XCTAssertEqual(values.map(\.count), [1_277, 2_860, 858, 858, 10, 1_277, 156, 156, 10])
        XCTAssertEqual(totals.reduce(0, +), 2_598_960)
        XCTAssertEqual(values.reduce(0) { $0 + $1.count }, 7_462)
    }
}
