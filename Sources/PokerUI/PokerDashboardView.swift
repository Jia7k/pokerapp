#if os(iOS)
import SwiftUI
import PokerCore

@MainActor public struct PokerDashboardView: View {
    @Bindable private var session: PokerSession

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedInput: LiveInput?
    @State private var presentedSheet: DashboardSheet?

    public init(session: PokerSession) {
        _session = Bindable(wrappedValue: session)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dashboardHeader

                Divider()
                    .overlay(PokerTheme.border.opacity(0.7))

                ScrollView {
                    LazyVStack(spacing: 20) {
                        ActionRecommendationView(
                            analysis: session.model.analysis,
                            pot: session.model.betting.pot
                        )

                        CardTableView(model: session.model) { slot in
                            focusedInput = nil
                            presentedSheet = .card(slot)
                        }

                        liveHandPanel
                        PokerStatsView(analysis: session.model.analysis)
                        strategyPanel
                    }
                    .frame(maxWidth: 760)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("dashboard.scroll")
                .scrollDismissesKeyboard(.interactively)
            }
            .background(PokerTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedInput = nil
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("keyboard.done")
                }
            }
        }
        .tint(PokerTheme.gold)
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if session.canUndoNewHand {
                undoBanner
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .card(let slot):
                CardSelectorView(model: session.model, initialSlot: slot) {
                    session.save()
                }
            case .setup:
                TableSetupView(session: session)
            case .about:
                RiverlineAboutView()
            }
        }
    }

    private var dashboardHeader: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 12) {
                    accessibilityBrand
                    Spacer(minLength: 8)
                    headerActions
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        brand
                        Spacer(minLength: 8)
                        headerActions
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        brand
                        headerActions
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PokerTheme.surface)
    }

    private var accessibilityBrand: some View {
        HStack(spacing: 8) {
            Image(systemName: "suit.spade.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(PokerTheme.gold)
                .accessibilityHidden(true)

            Text("Riverline")
                .font(.system(.headline, design: .serif).weight(.bold))
                .foregroundStyle(PokerTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .dynamicTypeSize(.medium ... .xxxLarge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Riverline, offline poker guide")
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image(systemName: "suit.spade.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(PokerTheme.gold)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("RIVERLINE")
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(PokerTheme.text)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Circle()
                        .fill(PokerTheme.green)
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)
                    Text("OFFLINE POKER GUIDE")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.7)
                        .foregroundStyle(PokerTheme.muted)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Riverline, offline poker guide")
    }

    private var headerActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                setupButton
                newHandButton
            }

            VStack(spacing: 8) {
                setupButton
                newHandButton
            }
        }
    }

    private var setupButton: some View {
        Button {
            focusedInput = nil
            presentedSheet = .setup
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.body.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(PokerTheme.text)
                .background(PokerTheme.raised, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(PokerTheme.border.opacity(0.7), lineWidth: 1)
                }
        }
        .buttonStyle(CasinoButtonStyle())
        .accessibilityLabel("Table setup")
        .accessibilityIdentifier("table.setup")
        .accessibilityHint("Opens bankroll, stack, blind, and advanced table settings.")
    }

    private var newHandButton: some View {
        Button {
            focusedInput = nil
            session.newHand()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.body.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(PokerTheme.cardInk)
                .background(PokerTheme.gold, in: Capsule())
        }
        .buttonStyle(CasinoButtonStyle())
        .accessibilityLabel("New hand")
        .accessibilityIdentifier("hand.new")
        .accessibilityHint("Clears the cards and current betting while preserving table balances.")
    }

    private var liveHandPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("LIVE HAND")
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(PokerTheme.gold)

                Text("Price the decision")
                    .font(.title2.bold())
                    .foregroundStyle(PokerTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label("Session bankroll", systemImage: "banknote")
                    .font(.subheadline)
                    .foregroundStyle(PokerTheme.muted)
                Spacer(minLength: 8)
                Text(PokerFormat.chips(session.model.bankroll))
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(PokerTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    liveInputField(
                        title: "Pot",
                        detail: "Before your call",
                        text: potBinding,
                        input: .pot,
                        identifier: "input.pot"
                    )
                    liveInputField(
                        title: "To call",
                        detail: "Additional chips",
                        text: callBinding,
                        input: .call,
                        identifier: "input.call"
                    )
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    liveInputField(
                        title: "Pot",
                        detail: "Before your call",
                        text: potBinding,
                        input: .pot,
                        identifier: "input.pot"
                    )
                    liveInputField(
                        title: "To call",
                        detail: "Additional chips",
                        text: callBinding,
                        input: .call,
                        identifier: "input.call"
                    )
                }
            }

            Divider()
                .overlay(PokerTheme.border.opacity(0.7))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 92), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                stackMetric("Your stack", value: session.model.betting.heroStack)
                stackMetric("Opponent", value: session.model.betting.opponentStack)
                stackMetric("Big blind", value: session.model.betting.bigBlind)
            }
        }
        .casinoPanel()
    }

    private func liveInputField(
        title: String,
        detail: String,
        text: Binding<String>,
        input: LiveInput,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PokerTheme.text)

            TextField("0", text: text)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(PokerTheme.text)
                .keyboardType(.decimalPad)
                .focused($focusedInput, equals: input)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 12)
                .background(PokerTheme.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            focusedInput == input ? PokerTheme.gold : PokerTheme.border.opacity(0.7),
                            lineWidth: focusedInput == input ? 1.5 : 1
                        )
                }
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)

            Text(detail)
                .font(.caption)
                .foregroundStyle(PokerTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stackMetric(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(PokerTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(PokerFormat.chips(value))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(PokerTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(PokerTheme.raised.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private var strategyPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("STRATEGY CONTEXT")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(PokerTheme.gold)

                    Text("Tune the read")
                        .font(.title2.bold())
                        .foregroundStyle(PokerTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    focusedInput = nil
                    presentedSheet = .about
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(PokerTheme.gold)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(CasinoButtonStyle())
                .accessibilityLabel("About Riverline recommendations")
                .accessibilityHint("Explains the method and its limits.")
            }

            Divider()
                .overlay(PokerTheme.border.opacity(0.7))

            VStack(alignment: .leading, spacing: 8) {
                Text("Position")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PokerTheme.text)

                Picker("Position", selection: positionBinding) {
                    ForEach(Position.allCases, id: \.self) { position in
                        Text(position.name).tag(position)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 12)
                .background(PokerTheme.raised, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("Table position")
                .accessibilityValue(session.model.position.name)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Preflop spot")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PokerTheme.text)

                Picker("Preflop spot", selection: situationBinding) {
                    ForEach(PreflopSituation.allCases, id: \.self) { situation in
                        Text(situationName(situation)).tag(situation)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 12)
                .background(PokerTheme.raised, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("Preflop situation")
                .accessibilityValue(situationName(session.model.preflopSituation))
            }

            Toggle(isOn: aggressorBinding) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Preflop aggressor")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PokerTheme.text)
                    Text("Used for postflop continuation-bet guidance")
                        .font(.caption)
                        .foregroundStyle(PokerTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(PokerTheme.green)
            .frame(minHeight: 48)
            .accessibilityIdentifier("strategy.aggressor")
        }
        .casinoPanel()
    }

    private var undoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PokerTheme.green)
                .accessibilityHidden(true)

            Text("New hand started")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PokerTheme.text)

            Spacer(minLength: 8)

            Button("Undo") {
                session.undoNewHand()
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(PokerTheme.gold)
            .frame(minHeight: 44)
            .accessibilityIdentifier("hand.undo")
            .accessibilityHint("Restores the previous hand and betting state.")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().overlay(PokerTheme.border)
        }
    }

    private var potBinding: Binding<String> {
        Binding(
            get: { session.potText },
            set: { session.updatePot($0) }
        )
    }

    private var callBinding: Binding<String> {
        Binding(
            get: { session.callText },
            set: { session.updateCall($0) }
        )
    }

    private var positionBinding: Binding<Position> {
        Binding(
            get: { session.model.position },
            set: { session.setPosition($0) }
        )
    }

    private var situationBinding: Binding<PreflopSituation> {
        Binding(
            get: { session.model.preflopSituation },
            set: { session.setSituation($0) }
        )
    }

    private var aggressorBinding: Binding<Bool> {
        Binding(
            get: { session.model.isPreflopAggressor },
            set: { session.setAggressor($0) }
        )
    }

    private func situationName(_ situation: PreflopSituation) -> String {
        switch situation {
        case .unopened: "Unopened pot"
        case .facingOpenRaise: "Facing an open raise"
        }
    }

    private enum LiveInput: Hashable {
        case pot, call
    }

    private enum DashboardSheet: Identifiable {
        case card(CardSlot)
        case setup
        case about

        var id: String {
            switch self {
            case .card(let slot): "card.\(PokerFormat.slotID(slot))"
            case .setup: "setup"
            case .about: "about"
            }
        }
    }
}

@MainActor
private struct RiverlineAboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("A practical table guide", systemImage: "suit.spade.fill")
                            .font(.title2.bold())
                            .foregroundStyle(PokerTheme.gold)

                        Text("Riverline offers quick poker guidance while keeping every choice and chip movement in your hands.")
                            .font(.body)
                            .foregroundStyle(PokerTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    aboutPoint(
                        icon: "wifi.slash",
                        title: "Private and offline",
                        detail: "The app works entirely on this device and makes no network requests."
                    )
                    aboutPoint(
                        icon: "square.grid.3x3",
                        title: "Simplified preflop ranges",
                        detail: "Six-seat presets use the nearest supported stack depth. They are guidance, not solver output."
                    )
                    aboutPoint(
                        icon: "percent",
                        title: "Draw chance is not win equity",
                        detail: "Postflop estimates describe listed completion cards in a heads-up model. They do not model an opponent’s full range."
                    )
                    aboutPoint(
                        icon: "hand.tap",
                        title: "You record the action",
                        detail: "Recommendations never move chips. Update the pot, call, and table stacks to match the live hand."
                    )
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(PokerTheme.background.ignoresSafeArea())
            .navigationTitle("About Riverline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PokerTheme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func aboutPoint(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(PokerTheme.green)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PokerTheme.text)
                Text(detail)
                    .font(.body)
                    .foregroundStyle(PokerTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
