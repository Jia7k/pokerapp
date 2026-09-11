#if os(iOS)
import SwiftUI
import PokerCore

@MainActor public struct CardTableView: View {
    private let model: PokerViewModel
    private let onSelect: (CardSlot) -> Void

    @ScaledMetric(relativeTo: .body) private var heroCardWidth: CGFloat = 82
    @ScaledMetric(relativeTo: .body) private var heroCardHeight: CGFloat = 116
    @ScaledMetric(relativeTo: .body) private var boardCardWidth: CGFloat = 48
    @ScaledMetric(relativeTo: .body) private var boardCardHeight: CGFloat = 72

    public init(model: PokerViewModel, onSelect: @escaping (CardSlot) -> Void) {
        self.model = model
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Your cards")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(PokerTheme.text)

                Spacer(minLength: 8)

                if let handName = model.analysis.hand?.category.name {
                    Text(handName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PokerTheme.gold)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Current hand: \(handName)")
                }
            }

            HStack(alignment: .top, spacing: 12) {
                cardButton(for: .hole(0), width: min(heroCardWidth, 96), height: min(heroCardHeight, 136))
                cardButton(for: .hole(1), width: min(heroCardWidth, 96), height: min(heroCardHeight, 136))
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Hole cards")

            VStack(alignment: .leading, spacing: 12) {
                Text("Community")
                    .font(.headline)
                    .foregroundStyle(PokerTheme.text)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        flopGroup
                        singleCardGroup(title: "Turn", slot: .turn)
                        singleCardGroup(title: "River", slot: .river)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        flopGroup
                        HStack(alignment: .top, spacing: 12) {
                            singleCardGroup(title: "Turn", slot: .turn)
                            singleCardGroup(title: "River", slot: .river)
                        }
                    }
                }
            }
        }
        .casinoPanel()
    }

    private var flopGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            streetLabel("Flop")
            HStack(spacing: 6) {
                cardButton(for: .flop(0), width: max(44, min(boardCardWidth, 62)), height: max(64, min(boardCardHeight, 90)), compact: true)
                cardButton(for: .flop(1), width: max(44, min(boardCardWidth, 62)), height: max(64, min(boardCardHeight, 90)), compact: true)
                cardButton(for: .flop(2), width: max(44, min(boardCardWidth, 62)), height: max(64, min(boardCardHeight, 90)), compact: true)
            }
        }
    }

    private func singleCardGroup(title: String, slot: CardSlot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            streetLabel(title)
            cardButton(for: slot, width: max(44, min(boardCardWidth, 62)), height: max(64, min(boardCardHeight, 90)), compact: true)
        }
    }

    private func streetLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(PokerTheme.muted)
    }

    private func cardButton(
        for slot: CardSlot,
        width: CGFloat,
        height: CGFloat,
        compact: Bool = false
    ) -> some View {
        let card = try? model.card(at: slot)
        let enabled = isEnabled(slot)

        return Button {
            onSelect(slot)
        } label: {
            PlayingCardFace(card: card, width: width, height: height, compact: compact)
        }
        .buttonStyle(CasinoButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.42)
        .accessibilityIdentifier("card.\(PokerFormat.slotID(slot))")
        .accessibilityLabel(cardAccessibilityLabel(card: card, slot: slot))
        .accessibilityHint(enabled ? "Opens the card selector." : "Complete the earlier community cards first.")
    }

    private func isEnabled(_ slot: CardSlot) -> Bool {
        switch slot {
        case .turn:
            model.boardCards.prefix(3).allSatisfy { $0 != nil }
        case .river:
            model.boardCards.prefix(4).allSatisfy { $0 != nil }
        default:
            true
        }
    }

    private func cardAccessibilityLabel(card: Card?, slot: CardSlot) -> String {
        let value = card.map(PokerFormat.cardName) ?? "empty"
        return "\(PokerFormat.slotName(slot)), \(value)"
    }
}

private struct PlayingCardFace: View {
    let card: Card?
    let width: CGFloat
    let height: CGFloat
    let compact: Bool

    var body: some View {
        ZStack {
            if let card {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PokerTheme.ivory)
                    .shadow(color: .black.opacity(0.22), radius: 6, y: 3)

                if compact {
                    compactCardContent(card)
                } else {
                    fullCardContent(card)
                }
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PokerTheme.raised.opacity(0.34))

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        PokerTheme.muted.opacity(0.65),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                    )

                Image(systemName: "plus")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(PokerTheme.muted)
            }
        }
        .frame(width: width, height: height)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }

    private func compactCardContent(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(card.rank.symbol)
                .font(.headline.weight(.bold))
                .minimumScaleFactor(0.65)

            Spacer(minLength: 2)

            Text(card.suit.rawValue)
                .font(.title2.weight(.semibold))
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .foregroundStyle(ink(for: card.suit))
        .padding(7)
    }

    private func fullCardContent(_ card: Card) -> some View {
        VStack(spacing: 0) {
            HStack {
                corner(for: card)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            Text(card.suit.rawValue)
                .font(.largeTitle.weight(.medium))
                .minimumScaleFactor(0.55)
                .foregroundStyle(ink(for: card.suit))

            Spacer(minLength: 0)

            HStack {
                Spacer(minLength: 0)
                corner(for: card)
                    .rotationEffect(.degrees(180))
            }
        }
        .padding(8)
    }

    private func corner(for card: Card) -> some View {
        VStack(spacing: -2) {
            Text(card.rank.symbol)
                .font(.headline.weight(.bold))
            Text(card.suit.rawValue)
                .font(.subheadline.weight(.semibold))
        }
        .minimumScaleFactor(0.65)
        .foregroundStyle(ink(for: card.suit))
    }

    private func ink(for suit: Suit) -> Color {
        switch suit {
        case .hearts, .diamonds: PokerTheme.cardRed
        case .spades, .clubs: PokerTheme.cardInk
        }
    }
}
#endif
