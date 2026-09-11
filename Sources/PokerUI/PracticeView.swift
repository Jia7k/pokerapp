#if os(iOS)
import SwiftUI
import PokerCore

/// A self-contained drill screen. Its model never mutates the live table session.
@MainActor public struct PracticeView: View {
    @Bindable private var model: PracticeViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var accessibilityFocus: PracticeFocus?
    @ScaledMetric(relativeTo: .body) private var holeCardWidth: CGFloat = 82
    @ScaledMetric(relativeTo: .body) private var holeCardHeight: CGFloat = 116
    @ScaledMetric(relativeTo: .body) private var flopCardWidth: CGFloat = 54
    @ScaledMetric(relativeTo: .body) private var flopCardHeight: CGFloat = 78

    public init(model: PracticeViewModel) {
        _model = Bindable(wrappedValue: model)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider().overlay(PokerTheme.border.opacity(0.7))

                ScrollViewReader { reader in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let scenario = model.currentScenario {
                                scenarioPanel(scenario)
                                    .id("practice.top")
                                situationPanel(scenario)

                                if let feedback = model.feedback {
                                    feedbackPanel(feedback, scenario: scenario)
                                } else if model.canAnswer {
                                    choicesPanel
                                }
                            }

                            if let message = model.errorMessage {
                                unavailablePanel(message)
                            }

                            Text("Practice uses the same simplified heads-up heuristics as the table. It is not a GTO solver. Your score lasts for this session.")
                                .font(.footnote)
                                .foregroundStyle(PokerTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: 760)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("practice.scroll")
                    .onChange(of: model.feedback?.scenarioID) { _, scenarioID in
                        if scenarioID != nil {
                            accessibilityFocus = .result
                        } else if model.currentScenario != nil {
                            reader.scrollTo("practice.top", anchor: .top)
                            accessibilityFocus = .progress
                        }
                    }
                }
            }
            .background(PokerTheme.background.ignoresSafeArea())
        }
        .tint(PokerTheme.gold)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                title
                Spacer(minLength: 8)
                score
            }
            VStack(alignment: .leading, spacing: 8) {
                title
                score
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PokerTheme.surface)
    }

    private var title: some View {
        HStack(spacing: 10) {
            Image(systemName: "suit.spade.fill")
                .foregroundStyle(PokerTheme.gold)
                .accessibilityHidden(true)
            Text("Practice")
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(PokerTheme.text)
                .fixedSize()
        }
        .dynamicTypeSize(.medium ... .xxxLarge)
        .accessibilityAddTraits(.isHeader)
    }

    private var score: some View {
        Text("Correct: \(model.correctCount)/\(model.attemptCount)")
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(PokerTheme.gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(PokerTheme.gold.opacity(0.08), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("practice.score")
    }

    private func scenarioPanel(_ scenario: PracticeScenario) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("FLOP \(model.scenarioNumber) OF \(model.scenarioCount)")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(PokerTheme.gold)
                .accessibilityLabel("Flop \(model.scenarioNumber) of \(model.scenarioCount)")
                .accessibilityIdentifier("practice.progress")
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($accessibilityFocus, equals: .progress)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 20) {
                    holeCards(scenario)
                    flopCards(scenario)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 28) {
                        holeCards(scenario)
                        flopCards(scenario)
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        holeCards(scenario)
                        flopCards(scenario)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .casinoPanel()
    }

    private func holeCards(_ scenario: PracticeScenario) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            cardGroupTitle("Your cards")
            HStack(spacing: 12) {
                ForEach(Array(scenario.holeCards.enumerated()), id: \.offset) { index, card in
                    visibleCard(
                        card, slot: "Hole card \(index + 1)", identifier: "practice.hole.\(index)",
                        width: min(holeCardWidth, 96), height: min(holeCardHeight, 136), compact: false
                    )
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func flopCards(_ scenario: PracticeScenario) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            cardGroupTitle("Flop")
            HStack(spacing: 8) {
                ForEach(Array(scenario.flop.enumerated()), id: \.offset) { index, card in
                    visibleCard(
                        card, slot: "Flop card \(index + 1)", identifier: "practice.flop.\(index)",
                        width: min(flopCardWidth, 68), height: min(flopCardHeight, 98), compact: true
                    )
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func cardGroupTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(PokerTheme.text)
            .accessibilityAddTraits(.isHeader)
    }

    private func visibleCard(
        _ card: Card, slot: String, identifier: String,
        width: CGFloat, height: CGFloat, compact: Bool
    ) -> some View {
        PlayingCardFace(card: card, width: width, height: height, compact: compact)
            .dynamicTypeSize(.medium ... .xxxLarge)
            .accessibilityHidden(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(slot), \(PokerFormat.cardName(card))")
            .accessibilityAddTraits(.isImage)
            .accessibilityIdentifier(identifier)
    }

    private func situationPanel(_ scenario: PracticeScenario) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) {
                    potMetric(scenario)
                    stackMetric(scenario)
                }
            } else {
                HStack(alignment: .top, spacing: 20) {
                    potMetric(scenario)
                    stackMetric(scenario)
                }
            }

            Divider().overlay(PokerTheme.border)

            Text(scenario.betting.amountToCall > 0
                 ? "To call: \(PokerFormat.chips(scenario.betting.callCost)) chips"
                 : "To call: 0 chips · Checked to you")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(scenario.betting.amountToCall > 0 ? PokerTheme.gold : PokerTheme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("practice.toCall")

            Text(scenario.isPreflopAggressor
                 ? "You were the preflop aggressor."
                 : "You were not the preflop aggressor.")
                .font(.subheadline)
                .foregroundStyle(PokerTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("practice.aggressor")
        }
        .casinoPanel()
    }

    private func potMetric(_ scenario: PracticeScenario) -> some View {
        metric("Pot", value: "\(PokerFormat.chips(scenario.betting.pot)) chips", identifier: "practice.pot")
    }

    private func stackMetric(_ scenario: PracticeScenario) -> some View {
        metric("Effective stack", value: "\(PokerFormat.chips(scenario.betting.effectiveStack)) chips", identifier: "practice.effectiveStack")
    }

    private func metric(_ title: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(PokerTheme.muted)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(PokerTheme.text)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityIdentifier(identifier)
    }

    private var choicesPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What's your move?")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(PokerTheme.text)
                .accessibilityAddTraits(.isHeader)

            Text("Read the texture. Work out the SPR.")
                .font(.subheadline)
                .foregroundStyle(PokerTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    choiceButton(.bet)
                    choiceButton(.check)
                    choiceButton(.fold)
                }
            } else {
                HStack(spacing: 10) {
                    choiceButton(.bet)
                    choiceButton(.check)
                    choiceButton(.fold)
                }
            }
        }
    }

    private func choiceButton(_ choice: PracticeChoice) -> some View {
        Button {
            model.submit(choice)
        } label: {
            Text(choice.title)
                .font(.headline)
                .foregroundStyle(choice == .bet ? PokerTheme.background : choiceColor(choice))
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, 8)
                .background(choice == .bet ? PokerTheme.green : PokerTheme.raised, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(choiceColor(choice).opacity(0.4), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(CasinoButtonStyle())
        .disabled(!model.canAnswer)
        .accessibilityIdentifier("practice.\(choice.rawValue)")
        .accessibilityHint("Grades this choice and shows an explanation.")
    }

    private func choiceColor(_ choice: PracticeChoice) -> Color {
        switch choice {
        case .bet: PokerTheme.green
        case .check: PokerTheme.text
        case .fold: PokerTheme.red
        }
    }

    private func feedbackPanel(_ feedback: PracticeFeedback, scenario: PracticeScenario) -> some View {
        let tint = feedback.isCorrect ? PokerTheme.green : PokerTheme.red
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: feedback.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)

                Text(feedback.isCorrect ? "CORRECT" : "INCORRECT")
                    .font(.system(.title, design: .serif).weight(.bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .accessibilityIdentifier("practice.result")
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($accessibilityFocus, equals: .result)

                Text("You chose \(feedback.chosenChoice.title).")
                    .font(.subheadline)
                    .foregroundStyle(PokerTheme.muted)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Recommended: \(actionDescription(feedback.analysis.recommendation.action, pot: scenario.betting.pot))")
                    .font(.headline)
                    .foregroundStyle(PokerTheme.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(feedback.explanation)
                    .font(.body)
                    .foregroundStyle(PokerTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("practice.explanation")
            }

            Divider().overlay(PokerTheme.border)

            VStack(alignment: .leading, spacing: 16) {
                metric("Board texture", value: textureDescription(feedback.analysis.texture), identifier: "practice.texture")
                metric("Stack-to-pot ratio", value: PokerFormat.ratio(scenario.betting.stackToPotRatio), identifier: "practice.spr")
                Text("\(PokerFormat.chips(scenario.betting.effectiveStack)) stack ÷ \(PokerFormat.chips(scenario.betting.pot)) pot")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(PokerTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                model.nextScenario()
            } label: {
                HStack(spacing: 10) {
                    Text("Next Scenario")
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "arrow.right")
                        .accessibilityHidden(true)
                }
                .font(.headline)
                .foregroundStyle(PokerTheme.background)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(PokerTheme.gold, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(CasinoButtonStyle())
            .accessibilityIdentifier("practice.next")
            .accessibilityHint("Loads another flop and keeps your score.")
        }
        .casinoPanel()
        .overlay(RoundedRectangle(cornerRadius: PokerTheme.radius).strokeBorder(tint.opacity(0.5), lineWidth: 1))
    }

    private func unavailablePanel(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Drill unavailable", systemImage: "exclamationmark.circle")
                .font(.headline)
                .foregroundStyle(PokerTheme.gold)
            Text(message)
                .font(.body)
                .foregroundStyle(PokerTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .casinoPanel()
    }

    private func textureDescription(_ report: BoardTextureReport) -> String {
        let texture: String
        switch report.texture {
        case .dryRainbow: texture = "Dry / Rainbow"
        case .wetConnected: texture = "Wet / Connected"
        case .monotone: texture = "Monotone"
        }
        return report.isPaired ? "\(texture) · Paired" : texture
    }

    private func actionDescription(_ action: PokerAction, pot: Double) -> String {
        switch action {
        case .bet(let amount):
            "Bet \(PokerFormat.chips(amount)) chips · \(PokerFormat.percent(amount / pot)) pot"
        case .allIn(let amount):
            "Bet all in · \(PokerFormat.chips(amount)) chips"
        case .check:
            "Check"
        case .fold:
            "Fold"
        case .call(let amount):
            "Call \(PokerFormat.chips(amount)) chips"
        case .raise(let amount):
            "Raise to \(PokerFormat.chips(amount)) chips"
        case .noAction:
            "No action"
        }
    }

    private enum PracticeFocus: Hashable {
        case progress, result
    }
}
#endif
