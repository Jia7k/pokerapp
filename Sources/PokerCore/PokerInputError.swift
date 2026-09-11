public enum PokerInputError: Error, Equatable, Sendable {
    case duplicateCard(Card)
    case invalidCardCount(actual: Int, expected: String)
    case invalidOutCount(Int)
    case invalidChipAmount
}
