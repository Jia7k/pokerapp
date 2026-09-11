import XCTest
import PokerCore

final class BettingStateTests: XCTestCase {
    func testShortCallRetainsMatchedChipsWhenBetIsMuchLarger() throws {
        let betting = BettingState(pot: 1e20, amountToCall: 1e20, heroStack: 1, opponentStack: 0)
        XCTAssertEqual(betting.contestablePot, 1)
        XCTAssertEqual(try betting.requiredEquity(), 0.5)
    }

    func testAllInCanUseFiniteRemainingStackWhenTotalContributionWouldOverflow() throws {
        let betting = BettingState(
            pot: 1e308, amountToCall: 1, heroStack: 1e308,
            opponentStack: 1e308, heroStreetContribution: 1e308
        )
        XCTAssertEqual(try betting.commitEffectiveStack(), .allIn(amount: 1e308))
    }

    func testOutstandingBetCountsTowardOpponentCoverage() throws {
        let betting = BettingState(pot: 200, amountToCall: 50, heroStack: 500, opponentStack: 0)
        XCTAssertEqual(betting.effectiveStack, 50)
        XCTAssertEqual(betting.stackToPotRatio, 0.25)
        XCTAssertEqual(betting.passiveAction(), .call(amount: 50))
        XCTAssertTrue(betting.closesBettingByCalling)
    }

    func testShortAllInCallExcludesUncallableExcessFromPotOdds() throws {
        let betting = BettingState(pot: 400, amountToCall: 300, heroStack: 100, opponentStack: 0)
        XCTAssertEqual(betting.contestablePot, 200)
        XCTAssertEqual(try betting.requiredEquity(), 1.0 / 3, accuracy: 1e-12)
        XCTAssertEqual(betting.passiveAction(), .allIn(amount: 100))
    }

    func testStandardPotOddsAndOrdinaryCall() throws {
        let betting = BettingState(pot: 150, amountToCall: 50)
        XCTAssertEqual(try betting.requiredEquity(), 0.25)
        XCTAssertEqual(betting.passiveAction(), .call(amount: 50))
        XCTAssertFalse(betting.closesBettingByCalling)
    }

    func testBetsRespectMinimumStackAndOpponentCoverage() throws {
        XCTAssertEqual(try BettingState(pot: 300).sizedBet(potFraction: 0.33), .bet(amount: 99))
        XCTAssertEqual(try BettingState(pot: 10).sizedBet(potFraction: 0.33), .bet(amount: 10))
        XCTAssertEqual(try BettingState(pot: 300, heroStack: 50).sizedBet(potFraction: 0.33), .allIn(amount: 50))
        XCTAssertEqual(try BettingState(pot: 300, opponentStack: 50).sizedBet(potFraction: 0.33), .bet(amount: 50))
        XCTAssertEqual(try BettingState(pot: 10, opponentStack: 5).sizedBet(potFraction: 0.33), .check)
    }

    func testRaiseIsTotalStreetContributionAndRespectsMinimum() throws {
        let betting = BettingState(pot: 100, amountToCall: 20, heroStreetContribution: 10, minimumRaiseIncrement: 20)
        XCTAssertEqual(try betting.sizedRaise(to: 90), .raise(to: 90))
        XCTAssertEqual(try betting.sizedRaise(to: 35), .raise(to: 50))
    }

    func testShortHeroMayShoveButCannotShortRaiseWithChipsBehind() throws {
        let shortHero = BettingState(pot: 100, amountToCall: 30, heroStack: 35, minimumRaiseIncrement: 30)
        XCTAssertEqual(try shortHero.sizedRaise(to: 90), .allIn(amount: 35))
        let shortOpponent = BettingState(pot: 100, amountToCall: 30, opponentStack: 5, minimumRaiseIncrement: 30)
        XCTAssertEqual(try shortOpponent.sizedRaise(to: 90), .call(amount: 30))
    }

    func testCommitmentDistinguishesHeroShoveFromMatchedBetAndCall() throws {
        XCTAssertEqual(try BettingState(pot: 100, heroStack: 80).commitEffectiveStack(), .allIn(amount: 80))
        XCTAssertEqual(try BettingState(pot: 100, opponentStack: 80).commitEffectiveStack(), .bet(amount: 80))
        XCTAssertEqual(try BettingState(pot: 100, amountToCall: 30, opponentStack: 0).commitEffectiveStack(), .call(amount: 30))
        XCTAssertEqual(try BettingState(heroStack: 0).commitEffectiveStack(), .noAction)
        XCTAssertNil(BettingState().stackToPotRatio)
    }

    func testInvalidNumbersAndInconsistentPotAreRejected() {
        for bad in [-1.0, .infinity, .nan] {
            XCTAssertThrowsError(try BettingState(pot: bad).validate())
            XCTAssertThrowsError(try BettingState(heroStack: bad).validate())
            XCTAssertThrowsError(try BettingState(opponentStack: bad).validate())
            XCTAssertThrowsError(try BettingState(amountToCall: bad).validate())
            XCTAssertThrowsError(try BettingState(heroStreetContribution: bad).validate())
            XCTAssertThrowsError(try BettingState(bigBlind: bad).validate())
        }
        XCTAssertThrowsError(try BettingState(bigBlind: 0).validate())
        XCTAssertThrowsError(try BettingState(pot: 20, amountToCall: 30).validate())
        XCTAssertThrowsError(try BettingState(pot: 20, amountToCall: 10, heroStreetContribution: 15).validate())
        XCTAssertThrowsError(try BettingState(minimumRaiseIncrement: 5).validate())
        XCTAssertThrowsError(try BettingState().sizedBet(potFraction: .nan))
        XCTAssertThrowsError(try BettingState(pot: 100, amountToCall: 20).sizedBet(potFraction: 0.33))
        XCTAssertThrowsError(try BettingState().sizedRaise(to: .infinity))
    }
}
