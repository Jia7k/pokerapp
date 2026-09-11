#if os(iOS)
import SwiftUI
import PokerCore

@MainActor public struct CardSelectorView: View {
    private let model: PokerViewModel
    private let onSelection: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeSlot: CardSlot
    @State private var selectedSuit: Suit
    @State private var errorMessage: String?
    @State private var feedbackTrigger = 0

    private let rankColumns = [GridItem(.adaptive(minimum: 64), spacing: 12)]
    private let suitColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    public init(
        model: PokerViewModel,
        initialSlot: CardSlot,
        onSelection: @escaping () -> Void = {}
    ) {
        self.model = model
        self.onSelection = onSelection
        _activeSlot = State(initialValue: initialSlot)
        let initialCard: Card? = try? model.card(at: initialSlot)
        _selectedSuit = State(initialValue: initialCard?.suit ?? .spades)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    slotSection
                    suitSection
                    rankSection
                    clearSection
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
            .background(PokerTheme.background.ignoresSafeArea())
            .navigationTitle("Choose a card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PokerTheme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PokerTheme.gold)
                        .accessibilityIdentifier("selector.done")
                }
            }
        }
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    private var slotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selecting \(PokerFormat.slotName(activeSlot))")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PokerTheme.text)
                .accessibilityIdentifier("selector.activeSlot")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CardSlot.allCases, id: \.self) { slot in
                        slotButton(slot)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var suitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suit")
                .font(.headline)
                .foregroundStyle(PokerTheme.text)

            LazyVGrid(columns: suitColumns, spacing: 10) {
                ForEach(Suit.allCases, id: \.self) { suit in
                    Button {
                        chooseSuit(suit)
                    } label: {
                        Text(suit.rawValue)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(suitControlInk(suit))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                selectedSuit == suit ? PokerTheme.ivory : PokerTheme.raised,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        selectedSuit == suit ? PokerTheme.gold : PokerTheme.border,
                                        lineWidth: selectedSuit == suit ? 2 : 1
                                    )
                            }
                    }
                    .buttonStyle(CasinoButtonStyle())
                    .accessibilityIdentifier("selector.suit.\(suitIdentifier(suit))")
                    .accessibilityLabel(suitName(suit))
                    .accessibilityAddTraits(selectedSuit == suit ? .isSelected : [])
                }
            }
        }
    }

    private var rankSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Rank")
                    .font(.headline)
                    .foregroundStyle(PokerTheme.text)

                Spacer()

                Text(suitName(selectedSuit))
                    .font(.subheadline)
                    .foregroundStyle(PokerTheme.muted)
            }

            LazyVGrid(columns: rankColumns, spacing: 12) {
                ForEach(ranks, id: \.self) { rank in
                    rankButton(rank)
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(PokerTheme.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var clearSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(role: .destructive) {
                clearCurrentCard()
            } label: {
                Label("Clear \(PokerFormat.slotName(activeSlot))", systemImage: "xmark.circle")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(PokerTheme.red)
                    .background(PokerTheme.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(PokerTheme.red.opacity(0.45), lineWidth: 1)
                    }
            }
            .buttonStyle(CasinoButtonStyle())
            .disabled(currentCard == nil)
            .opacity(currentCard == nil ? 0.45 : 1)
            .accessibilityIdentifier("selector.clear")
            .accessibilityHint(clearNote ?? "Removes the card from this slot.")

            if let clearNote {
                Text(clearNote)
                    .font(.footnote)
                    .foregroundStyle(PokerTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func slotButton(_ slot: CardSlot) -> some View {
        let isActive = slot == activeSlot
        let enabled = isSlotEnabled(slot)
        let card = try? model.card(at: slot)

        return Button {
            moveToSlot(slot)
        } label: {
            VStack(spacing: 2) {
                Text(PokerFormat.slotName(slot))
                    .font(.caption.weight(.semibold))
                Text(card.map { $0.description } ?? "Empty")
                    .font(.caption2)
                    .foregroundStyle(isActive ? PokerTheme.cardInk.opacity(0.75) : PokerTheme.muted)
            }
            .foregroundStyle(isActive ? PokerTheme.cardInk : PokerTheme.text)
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(
                isActive ? PokerTheme.ivory : PokerTheme.raised,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(isActive ? PokerTheme.gold : PokerTheme.border, lineWidth: isActive ? 2 : 1)
            }
        }
        .buttonStyle(CasinoButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.42)
        .accessibilityLabel("\(PokerFormat.slotName(slot)), \(card.map(PokerFormat.cardName) ?? "empty")")
        .accessibilityHint(enabled ? "Changes the active card slot." : "Complete the earlier community cards first.")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func rankButton(_ rank: Rank) -> some View {
        let card = Card(rank: rank, suit: selectedSuit)
        let isSelected = currentCard == card
        let isAvailable = availableCards.contains(card)

        return Button {
            select(card)
        } label: {
            ZStack {
                VStack(spacing: 2) {
                    Text(rank.symbol)
                        .font(.title3.weight(.bold))
                    Text(selectedSuit.rawValue)
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(isSelected ? PokerTheme.cardInk : suitInk(selectedSuit))

                if !isAvailable {
                    Image(systemName: "nosign")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(PokerTheme.red)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                isSelected ? PokerTheme.gold : PokerTheme.ivory,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? PokerTheme.gold : PokerTheme.border.opacity(0.55), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(CasinoButtonStyle())
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.38)
        .accessibilityIdentifier("selector.rank.\(rank.rawValue)")
        .accessibilityLabel(rankAccessibilityLabel(card, available: isAvailable, selected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var ranks: [Rank] {
        Rank.allCases.sorted(by: >)
    }

    private var currentCard: Card? {
        try? model.card(at: activeSlot)
    }

    private var availableCards: Set<Card> {
        Set((try? model.availableCards(for: activeSlot)) ?? [])
    }

    private var clearNote: String? {
        guard currentCard != nil else { return nil }
        switch activeSlot {
        case .flop where model.boardCards[3] != nil || model.boardCards[4] != nil:
            return "Clearing a flop card also removes the turn and river."
        case .turn where model.boardCards[4] != nil:
            return "Clearing the turn also removes the river."
        default:
            return nil
        }
    }

    private func chooseSuit(_ suit: Suit) {
        guard selectedSuit != suit else { return }
        errorMessage = nil
        selectedSuit = suit
        feedbackTrigger += 1
    }

    private func moveToSlot(_ slot: CardSlot) {
        guard slot != activeSlot, isSlotEnabled(slot) else { return }
        errorMessage = nil
        let update = {
            activeSlot = slot
            if let card = try? model.card(at: slot) {
                selectedSuit = card.suit
            }
        }
        if reduceMotion {
            update()
        } else {
            withAnimation(.easeInOut(duration: 0.2), update)
        }
        feedbackTrigger += 1
    }

    private func select(_ card: Card) {
        let previousCard = currentCard
        let streetSlots = slotsInCurrentStreet
        let streetWasComplete = streetSlots.allSatisfy { (try? model.card(at: $0)) != nil }

        do {
            try model.setCard(card, at: activeSlot)
            errorMessage = nil
            onSelection()

            if previousCard == card || streetWasComplete {
                feedbackTrigger += 1
                dismiss()
            } else if let next = nextEmptySlot(after: activeSlot, within: streetSlots) {
                moveToSlot(next)
            } else {
                feedbackTrigger += 1
                dismiss()
            }
        } catch {
            errorMessage = message(for: error)
        }
    }

    private func clearCurrentCard() {
        do {
            try model.setCard(nil, at: activeSlot)
            errorMessage = nil
            feedbackTrigger += 1
            onSelection()
        } catch {
            errorMessage = message(for: error)
        }
    }

    private var slotsInCurrentStreet: [CardSlot] {
        switch activeSlot {
        case .hole:
            [.hole(0), .hole(1)]
        case .flop:
            [.flop(0), .flop(1), .flop(2)]
        case .turn:
            [.turn]
        case .river:
            [.river]
        }
    }

    private func nextEmptySlot(after slot: CardSlot, within slots: [CardSlot]) -> CardSlot? {
        guard let index = slots.firstIndex(of: slot) else { return nil }
        let ordered = Array(slots.dropFirst(index + 1)) + Array(slots.prefix(index))
        return ordered.first { (try? model.card(at: $0)) == nil }
    }

    private func isSlotEnabled(_ slot: CardSlot) -> Bool {
        switch slot {
        case .turn:
            model.boardCards.prefix(3).allSatisfy { $0 != nil }
        case .river:
            model.boardCards.prefix(4).allSatisfy { $0 != nil }
        default:
            true
        }
    }

    private func rankAccessibilityLabel(_ card: Card, available: Bool, selected: Bool) -> String {
        var label = PokerFormat.cardName(card)
        if selected {
            label += ", selected"
        } else if !available {
            label += ", unavailable because it is already in use"
        } else {
            label += ", available"
        }
        return label
    }

    private func message(for error: Error) -> String {
        if let inputError = error as? PokerInputError {
            switch inputError {
            case .duplicateCard(let card):
                return "\(PokerFormat.cardName(card)) is already in use. Choose another card."
            case .invalidCardCount:
                return "That card cannot be used here. Choose another card."
            case .invalidOutCount, .invalidChipAmount:
                return "The card selection could not be updated. Try another card."
            }
        }
        return String(describing: error)
    }

    private func suitInk(_ suit: Suit) -> Color {
        switch suit {
        case .hearts, .diamonds: PokerTheme.cardRed
        case .spades, .clubs: PokerTheme.cardInk
        }
    }

    private func suitControlInk(_ suit: Suit) -> Color {
        if selectedSuit == suit { return suitInk(suit) }
        return switch suit {
        case .hearts, .diamonds: PokerTheme.red
        case .spades, .clubs: PokerTheme.text
        }
    }

    private func suitIdentifier(_ suit: Suit) -> String {
        switch suit {
        case .spades: "spades"
        case .hearts: "hearts"
        case .diamonds: "diamonds"
        case .clubs: "clubs"
        }
    }

    private func suitName(_ suit: Suit) -> String {
        switch suit {
        case .spades: "Spades"
        case .hearts: "Hearts"
        case .diamonds: "Diamonds"
        case .clubs: "Clubs"
        }
    }
}
#endif
