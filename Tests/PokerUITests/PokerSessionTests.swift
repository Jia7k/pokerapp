import Foundation
import XCTest
import PokerCore
@testable import PokerUI

@MainActor private final class MemoryStorage: SessionStorage {
    var data: Data?
    func load() -> Data? { data }
    func save(_ data: Data) { self.data = data }
}

private func card(_ rank: Rank, _ suit: Suit) -> Card { Card(rank: rank, suit: suit) }

final class PokerSessionTests: XCTestCase {
    func testDecimalParsingRejectsPartialAndNonfiniteInput() {
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(PokerFormat.parseChips(" 125.50 ", locale: us), 125.5)
        XCTAssertEqual(PokerFormat.parseChips(".5", locale: us), 0.5)
        XCTAssertEqual(PokerFormat.parseChips("12,5", locale: Locale(identifier: "fr_FR")), 12.5)
        for invalid in ["", ".", "12x", "-1", "NaN", "1e308", "1,500", "1.2.3"] {
            XCTAssertNil(PokerFormat.parseChips(invalid, locale: us), invalid)
        }
    }

    func testMissingProbabilityIsDifferentFromZeroProbability() {
        XCTAssertEqual(PokerFormat.percent(nil), "—")
        XCTAssertEqual(PokerFormat.percent(.nan), "—")
        XCTAssertNotEqual(PokerFormat.percent(0), "—")
        XCTAssertEqual(PokerFormat.chips(.infinity), "—")
    }

    func testSmallValuesStayNonzeroAndEditableAmountsRoundTrip() {
        let us = Locale(identifier: "en_US")
        for value in [0.004, 0.000_000_01, 12.3456789, 9_876_543.21] {
            XCTAssertEqual(PokerFormat.parseChips(PokerFormat.editable(value, locale: us), locale: us), value)
        }
        XCTAssertNotEqual(PokerFormat.chips(0.004), PokerFormat.chips(0))
        XCTAssertNotEqual(PokerFormat.percent(0.0004), PokerFormat.percent(0))
        XCTAssertNotEqual(PokerFormat.ratio(0.04), PokerFormat.ratio(0))
    }

    func testDraftValidatesAllFieldsAndBettingRelationship() throws {
        var draft = TableSetupDraft(configuration: TableConfiguration(bankroll: 5_000, betting: BettingState(pot: 100, amountToCall: 20)))
        let configuration = try draft.validated(locale: Locale(identifier: "en_US"))
        XCTAssertEqual(configuration.bankroll, 5_000)
        XCTAssertEqual(configuration.betting.amountToCall, 20)
        draft.heroStack = ""
        XCTAssertThrowsError(try draft.validated())
        draft.heroStack = "500"
        draft.bigBlind = "0"
        XCTAssertThrowsError(try draft.validated())
        draft.bigBlind = "10"
        draft.pot = "5"
        XCTAssertThrowsError(try draft.validated())
    }

    func testInvalidLiveTextClearsAdviceAndDoesNotReplaceLastValidSave() async throws {
        try await MainActor.run {
            let storage = MemoryStorage()
            let session = PokerSession(storage: storage)
            try session.model.setCard(card(.ace, .hearts), at: .hole(0))
            try session.model.setCard(card(.five, .hearts), at: .hole(1))
            session.updatePot("150")
            let saved = storage.data
            XCTAssertNotNil(saved)
            session.updatePot("")
            XCTAssertEqual(session.model.analysis.status, .invalidInput)
            XCTAssertNil(session.model.analysis.recommendation)
            XCTAssertEqual(storage.data, saved)
            session.updatePot("150")
            XCTAssertEqual(session.model.analysis.status, .ready)
            XCTAssertEqual(session.model.betting.pot, 150)
        }
    }

    func testRelaunchRestoresCardsAndRecomputesAdvice() async throws {
        try await MainActor.run {
            let storage = MemoryStorage()
            let session = PokerSession(storage: storage)
            try session.model.setCard(card(.ace, .hearts), at: .hole(0))
            try session.model.setCard(card(.seven, .hearts), at: .hole(1))
            try session.model.setCard(card(.king, .hearts), at: .flop(0))
            try session.model.setCard(card(.two, .hearts), at: .flop(1))
            try session.model.setCard(card(.nine, .clubs), at: .flop(2))
            session.updatePot("150")
            session.updateCall("50")
            session.save()
            let restored = PokerSession(storage: storage)
            XCTAssertEqual(restored.model.selectedCards.count, 5)
            XCTAssertEqual(restored.model.analysis.recommendation?.action, .fold)
            XCTAssertEqual(restored.model.analysis.outs?.count, 9)
            XCTAssertEqual(restored.potText, "150")
            XCTAssertEqual(restored.callText, "50")
        }
    }

    func testCorruptOrDuplicateSavedCardsRecoverToEmptyHand() async throws {
        try await MainActor.run {
            let storage = MemoryStorage()
            let session = PokerSession(storage: storage)
            var snapshot = try SessionSnapshot(model: session.model)
            snapshot.holeCards = [card(.ace, .hearts), card(.ace, .hearts)]
            storage.data = try JSONEncoder().encode(snapshot)
            XCTAssertTrue(PokerSession(storage: storage).model.selectedCards.isEmpty)
            snapshot.holeCards = [nil, nil]
            snapshot.boardCards[3] = card(.king, .spades)
            storage.data = try JSONEncoder().encode(snapshot)
            XCTAssertTrue(PokerSession(storage: storage).model.selectedCards.isEmpty)
            storage.data = Data("invalid json".utf8)
            XCTAssertTrue(PokerSession(storage: storage).model.selectedCards.isEmpty)
        }
    }

    func testConfigurationApplicationIsAtomicAndPreservesCards() async throws {
        try await MainActor.run {
            let session = PokerSession(storage: MemoryStorage())
            try session.model.setCard(card(.ace, .spades), at: .hole(0))
            try session.model.setCard(card(.king, .spades), at: .hole(1))
            let valid = TableConfiguration(bankroll: 2_000, betting: BettingState(pot: 20, amountToCall: 10, heroStack: 400, opponentStack: 390))
            try session.applyConfiguration(valid)
            XCTAssertEqual(session.model.bankroll, 2_000)
            XCTAssertEqual(session.model.betting.heroStack, 400)
            XCTAssertEqual(session.model.selectedCards.count, 2)
            XCTAssertEqual(session.model.analysis.chartDepth, .bb40)
            let before = session.model.analysis
            XCTAssertThrowsError(try session.applyConfiguration(TableConfiguration(bankroll: -1, betting: BettingState())))
            XCTAssertEqual(session.model.analysis, before)
            XCTAssertEqual(session.model.bankroll, 2_000)
        }
    }

    func testNewHandAndUndoPreserveSessionBalanceAndRestoreCards() async throws {
        try await MainActor.run {
            let session = PokerSession(storage: MemoryStorage())
            try session.model.setCard(card(.ace, .spades), at: .hole(0))
            try session.model.setCard(card(.king, .spades), at: .hole(1))
            let before = session.model.analysis
            session.newHand()
            XCTAssertTrue(session.model.selectedCards.isEmpty)
            XCTAssertTrue(session.canUndoNewHand)
            XCTAssertEqual(session.model.bankroll, 1_000)
            XCTAssertEqual(session.potText, "0")
            session.undoNewHand()
            XCTAssertEqual(session.model.analysis, before)
            XCTAssertEqual(session.model.selectedCards.count, 2)
            XCTAssertFalse(session.canUndoNewHand)
        }
    }
}
