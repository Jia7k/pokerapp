import XCTest
import PokerCore

final class CardDeckTests: XCTestCase {
    func testKnownCardsAreExcludedFromAUniqueDeck() throws {
        let known = cards("As Kh 2c")
        let remaining = try Deck.remaining(excluding: known)
        XCTAssertEqual(remaining.count, 49)
        XCTAssertEqual(Set(remaining).count, 49)
        XCTAssertTrue(Set(remaining).isDisjoint(with: known))
        XCTAssertEqual(Set(Deck.allCards.map(\.id)).count, 52)
    }

    func testDuplicateKnownCardsAreRejected() {
        XCTAssertThrowsError(try Deck.remaining(excluding: cards("As As"))) {
            XCTAssertEqual($0 as? PokerInputError, .duplicateCard(cards("As")[0]))
        }
    }

    func testDrawingExhaustsDeckWithoutRepeatsAndShufflePreservesCards() throws {
        var deck = try Deck()
        deck.shuffle()
        var dealt = Set<Card>()
        while let card = deck.draw() { XCTAssertTrue(dealt.insert(card).inserted) }
        XCTAssertEqual(dealt.count, 52)
        XCTAssertNil(deck.draw())
    }

    func testCardRoundTripsThroughJSONWithIdentityAndDisplay() throws {
        let ace = Card(rank: .ace, suit: .hearts)
        let decoded = try JSONDecoder().decode(Card.self, from: JSONEncoder().encode(ace))
        XCTAssertEqual(decoded, ace)
        XCTAssertEqual(decoded.description, "A♥")
        XCTAssertEqual(decoded.id, ace.id)
        XCTAssertEqual(Card(rank: .ten, suit: .clubs).description, "10♣")
    }
}
