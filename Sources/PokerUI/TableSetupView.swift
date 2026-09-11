#if os(iOS)
import SwiftUI
import PokerCore

@MainActor
public struct TableSetupView: View {
    private let session: PokerSession

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TableSetupDraft
    @State private var applyError: String?
    @FocusState private var focusedField: Field?

    public init(session: PokerSession) {
        self.session = session
        _draft = State(initialValue: TableSetupDraft(configuration: session.configuration))
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    setupField(
                        "Bankroll",
                        text: binding(for: \.bankroll),
                        field: .bankroll,
                        identifier: "setup.bankroll"
                    )
                } header: {
                    sectionHeader("Session bankroll")
                } footer: {
                    Text("A session record for context. Recommendations never move this balance.")
                }

                Section {
                    setupField(
                        "Your chips behind",
                        text: binding(for: \.heroStack),
                        field: .heroStack,
                        identifier: "setup.heroStack"
                    )
                    setupField(
                        "Opponent chips behind",
                        text: binding(for: \.opponentStack),
                        field: .opponentStack,
                        identifier: "setup.opponentStack"
                    )
                    setupField(
                        "Big blind",
                        text: bigBlindBinding,
                        field: .bigBlind,
                        identifier: "setup.bigBlind"
                    )
                } header: {
                    sectionHeader("Remaining table stacks")
                } footer: {
                    Text("Enter chips still available after any bets already made.")
                }

                Section {
                    setupField(
                        "Pot",
                        text: binding(for: \.pot),
                        field: .pot,
                        identifier: "setup.pot"
                    )
                    setupField(
                        "Amount to call",
                        text: binding(for: \.amountToCall),
                        field: .amountToCall,
                        identifier: "setup.call"
                    )
                } header: {
                    sectionHeader("Current decision")
                } footer: {
                    Text("The pot includes the opponent’s outstanding bet, before your call.")
                }

                Section {
                    setupField(
                        "Your street contribution",
                        text: binding(for: \.heroStreetContribution),
                        field: .heroStreetContribution,
                        identifier: "setup.contribution"
                    )
                    setupField(
                        "Minimum raise increment",
                        text: binding(for: \.minimumRaiseIncrement),
                        field: .minimumRaiseIncrement,
                        identifier: "setup.minRaise"
                    )
                } header: {
                    sectionHeader("Advanced street settings")
                } footer: {
                    Text("A raise-to amount includes your existing contribution on this street.")
                }

                if let displayedError {
                    Section {
                        Label {
                            Text(displayedError)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(PokerTheme.red)
                        .accessibilityIdentifier("setup.error")
                    }
                    .listRowBackground(PokerTheme.red.opacity(0.08))
                }
            }
            .scrollContentBackground(.hidden)
            .background(PokerTheme.background)
            .foregroundStyle(PokerTheme.text)
            .navigationTitle("Table setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PokerTheme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(PokerTheme.text)
                    .accessibilityIdentifier("setup.cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave ? PokerTheme.gold : PokerTheme.muted)
                    .disabled(!canSave)
                    .accessibilityIdentifier("setup.save")
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("keyboard.done")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var canSave: Bool {
        (try? draft.validated()) != nil
    }

    private var displayedError: String? {
        if let applyError { return applyError }
        do {
            _ = try draft.validated()
            return nil
        } catch {
            return String(describing: error)
        }
    }

    private func save() {
        do {
            let configuration = try draft.validated()
            try session.applyConfiguration(configuration)
            dismiss()
        } catch {
            applyError = String(describing: error)
        }
    }

    private func binding(for keyPath: WritableKeyPath<TableSetupDraft, String>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { value in
                draft[keyPath: keyPath] = value
                applyError = nil
            }
        )
    }

    private var bigBlindBinding: Binding<String> {
        Binding(
            get: { draft.bigBlind },
            set: { value in
                let oldBlind = PokerFormat.parseChips(draft.bigBlind)
                let oldMinimum = PokerFormat.parseChips(draft.minimumRaiseIncrement)
                let minimumMatchedBlind = draft.minimumRaiseIncrement == draft.bigBlind ||
                    (oldBlind != nil && oldBlind == oldMinimum)

                draft.bigBlind = value
                if minimumMatchedBlind {
                    draft.minimumRaiseIncrement = value
                }
                applyError = nil
            }
        )
    }

    private func setupField(
        _ title: String,
        text: Binding<String>,
        field: Field,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PokerTheme.text)
                .fixedSize(horizontal: false, vertical: true)

            TextField("0", text: text)
                .font(.body.monospacedDigit())
                .foregroundStyle(PokerTheme.text)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .background(PokerTheme.raised, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            focusedField == field ? PokerTheme.gold : PokerTheme.border.opacity(0.65),
                            lineWidth: focusedField == field ? 1.5 : 1
                        )
                }
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
        .padding(.vertical, 4)
        .listRowBackground(PokerTheme.surface)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(PokerTheme.gold)
    }

    private enum Field: Hashable {
        case bankroll
        case heroStack
        case opponentStack
        case bigBlind
        case pot
        case amountToCall
        case heroStreetContribution
        case minimumRaiseIncrement
    }
}
#endif
