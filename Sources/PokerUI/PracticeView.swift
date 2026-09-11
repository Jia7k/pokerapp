#if os(iOS)
import SwiftUI
import PokerCore

/// A single-screen drill that keeps the question and its controls in view.
@MainActor public struct PracticeView: View {
    @Bindable private var model: PracticeViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var accessibilityFocus: PracticeFocus?

    public init(model: PracticeViewModel) {
        _model = Bindable(wrappedValue: model)
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let layout = PracticeLayout(size: geometry.size, typeSize: dynamicTypeSize)
                VStack(spacing: layout.gap) {
                    header(layout)

                    if let scenario = model.currentScenario {
                        if layout.isLandscape {
                            HStack(spacing: layout.gap) {
                                scenarioPanel(scenario, layout: layout)
                                    .frame(width: layout.contentWidth * 0.47, height: layout.bodyHeight)
                                decisionPanel(scenario, layout: layout)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        } else {
                            scenarioPanel(scenario, layout: layout)
                            decisionPanel(scenario, layout: layout)
                                .frame(maxHeight: .infinity)
                        }
                    } else {
                        unavailablePanel(model.errorMessage ?? "No drill is available.", layout: layout)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }

                    if !layout.isLandscape {
                        calibration(layout)
                    }
                }
                .padding(layout.outerPadding)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
            .background(PokerTheme.background.ignoresSafeArea())
        }
        .tint(PokerTheme.gold)
        .preferredColorScheme(.dark)
        .onChange(of: model.feedback?.scenarioID) { _, scenarioID in
            accessibilityFocus = scenarioID == nil ? .progress : .result
        }
    }

    private func header(_ layout: PracticeLayout) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: layout.titleFont - 3, weight: .semibold))
                    .foregroundStyle(PokerTheme.gold)
                    .accessibilityHidden(true)
                Text("Practice")
                    .font(.system(size: layout.titleFont, weight: .bold, design: .serif))
                    .foregroundStyle(PokerTheme.text)
            }
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 4)
            if layout.isLandscape {
                calibration(layout)
                Spacer(minLength: 4)
            }
            Text("Correct: \(model.correctCount)/\(model.attemptCount)")
                .font(.system(size: layout.bodyFont, weight: .semibold).monospacedDigit())
                .foregroundStyle(PokerTheme.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(PokerTheme.gold.opacity(0.09), in: Capsule())
                .accessibilityIdentifier("practice.score")
        }
        .frame(height: layout.headerHeight)
    }

    private func calibration(_ layout: PracticeLayout) -> some View {
        Text("Offline · Heuristic practice")
            .font(.system(size: layout.captionFont))
            .foregroundStyle(PokerTheme.muted)
            .lineLimit(1)
            .accessibilityLabel("Offline practice uses simplified heads-up heuristics, not a GTO solver. Your score lasts for this session. Topic accuracy is saved on this device.")
    }

    private func scenarioPanel(_ scenario: PracticeScenario, layout: PracticeLayout) -> some View {
        let width = layout.isLandscape ? layout.contentWidth * 0.47 : layout.contentWidth
        let cardWidth = min(layout.cardHeight / 1.4, max(38, (width - 2 * layout.panelPadding - 42) / 5))
        return VStack(alignment: .leading, spacing: layout.sectionGap) {
            HStack(alignment: .top, spacing: 12) {
                cardGroup(scenario.holeCards, holeCards: true, width: cardWidth, layout: layout)
                Spacer(minLength: 0)
                cardGroup(scenario.flop, holeCards: false, width: cardWidth, layout: layout)
            }

            Divider().overlay(PokerTheme.border)

            HStack(alignment: .top, spacing: 8) {
                chipMetric("Pot", value: scenario.betting.pot, identifier: "practice.pot", layout: layout)
                chipMetric("Effective stack", value: scenario.betting.effectiveStack, identifier: "practice.effectiveStack", layout: layout)
                chipMetric("To call", value: scenario.betting.callCost, identifier: "practice.toCall", layout: layout)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(bettingContext(scenario.betting))
                    .foregroundStyle(scenario.betting.amountToCall == 0 ? PokerTheme.muted : PokerTheme.gold)
                Spacer(minLength: 0)
                Text(scenario.isPreflopAggressor ? "Aggressor: You" : "Aggressor: Not you")
                    .foregroundStyle(PokerTheme.muted)
                    .accessibilityLabel(scenario.isPreflopAggressor ? "You were the preflop aggressor." : "You were not the preflop aggressor.")
                    .accessibilityIdentifier("practice.aggressor")
            }
            .font(.system(size: layout.captionFont))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .padding(layout.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: layout.isLandscape ? .infinity : nil, alignment: .center)
        .background(PokerTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(PokerTheme.border.opacity(0.65), lineWidth: 1))
    }

    private func cardGroup(_ cards: [Card], holeCards: Bool, width: CGFloat, layout: PracticeLayout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if holeCards {
                Text("YOUR CARDS")
                    .foregroundStyle(PokerTheme.muted)
            } else {
                Text("FLOP")
                    .foregroundStyle(PokerTheme.gold)
                    .accessibilityLabel("Flop")
                    .accessibilityIdentifier("practice.progress")
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($accessibilityFocus, equals: .progress)
            }
            HStack(spacing: 6) {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    PlayingCardFace(card: card, width: width, height: width * 1.4, compact: true)
                        .dynamicTypeSize(.small ... .large)
                        .accessibilityHidden(false)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(holeCards ? "Hole" : "Flop") card \(index + 1), \(PokerFormat.cardName(card))")
                        .accessibilityAddTraits(.isImage)
                        .accessibilityIdentifier("practice.\(holeCards ? "hole" : "flop").\(index)")
                }
            }
        }
        .font(.system(size: layout.captionFont, weight: .semibold))
        .lineLimit(1)
    }

    private func bettingContext(_ betting: BettingState) -> String {
        guard betting.amountToCall > 0 else { return "Checked to you" }
        if betting.opponentStack == 0 { return "Facing an all-in" }
        if betting.heroStack <= betting.amountToCall { return "Call puts you all-in" }
        return "Facing a bet"
    }

    private func chipMetric(_ title: String, value: Double, identifier: String, layout: PracticeLayout) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: layout.captionFont))
                .foregroundStyle(PokerTheme.muted)
            Text(PokerFormat.chips(value))
                .font(.system(size: layout.metricFont, weight: .semibold).monospacedDigit())
                .foregroundStyle(PokerTheme.text)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(PokerFormat.chips(value)) chips")
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func decisionPanel(_ scenario: PracticeScenario, layout: PracticeLayout) -> some View {
        if let feedback = model.feedback {
            feedbackPanel(feedback, scenario: scenario, layout: layout)
        } else if model.canAnswer {
            choicesPanel(layout)
        }
    }

    private func choicesPanel(_ layout: PracticeLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.sectionGap) {
            Text("What's your move?")
                .font(.system(size: layout.questionFont, weight: .semibold, design: .serif))
                .foregroundStyle(PokerTheme.text)
                .accessibilityAddTraits(.isHeader)
            Text("Read the board texture.\nWork out the stack-to-pot ratio.")
                .font(.system(size: layout.bodyFont))
                .foregroundStyle(PokerTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            HStack(spacing: 8) {
                ForEach(model.availableChoices) { choice in
                    choiceButton(choice, layout: layout)
                }
            }
        }
        .padding(layout.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PokerTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func choiceButton(_ choice: PracticeChoice, layout: PracticeLayout) -> some View {
        Button { model.submit(choice) } label: {
            Text(choice.title)
                .font(.system(size: layout.buttonFont, weight: .semibold))
                .foregroundStyle(isAggressive(choice) ? PokerTheme.background : choiceColor(choice))
                .frame(maxWidth: .infinity)
                .frame(height: layout.buttonHeight)
                .background(isAggressive(choice) ? PokerTheme.green : PokerTheme.raised, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(choiceColor(choice).opacity(0.4), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(CasinoButtonStyle())
        .disabled(!model.canAnswer)
        .accessibilityIdentifier("practice.\(choice.rawValue)")
        .accessibilityHint("Grades this choice and shows an explanation.")
    }

    private func feedbackPanel(_ feedback: PracticeFeedback, scenario: PracticeScenario, layout: PracticeLayout) -> some View {
        let tint = feedback.isCorrect ? PokerTheme.green : PokerTheme.red
        return VStack(alignment: .leading, spacing: layout.feedbackGap) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(feedback.isCorrect ? "CORRECT" : "INCORRECT")
                    .font(.system(size: layout.resultFont, weight: .bold, design: .serif))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .accessibilityIdentifier("practice.result")
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($accessibilityFocus, equals: .result)
                Spacer(minLength: 0)
                Text("You: \(feedback.chosenChoice.title)")
                    .font(.system(size: layout.captionFont))
                    .foregroundStyle(PokerTheme.muted)
                    .lineLimit(1)
                    .accessibilityLabel("You chose \(feedback.chosenChoice.title).")
            }

            Text("Suggested: \(actionDescription(feedback.analysis.recommendation.action, choice: feedback.correctChoice, pot: scenario.betting.pot))")
                .font(.system(size: layout.bodyFont, weight: .semibold))
                .foregroundStyle(PokerTheme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("practice.recommendation")

            Text(feedback.explanation)
                .font(.system(size: layout.bodyFont))
                .foregroundStyle(PokerTheme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("practice.explanation")

            Spacer(minLength: 0)

            topicAccuracy(feedback, layout: layout)

            HStack(alignment: .top, spacing: 10) {
                resultMetric("Texture", value: textureDescription(feedback.analysis.texture), identifier: "practice.texture", layout: layout)
                resultMetric("SPR", value: PokerFormat.ratio(scenario.betting.stackToPotRatio), identifier: "practice.spr", layout: layout)
            }

            Button { model.nextScenario() } label: {
                HStack(spacing: 8) {
                    Text("Next Scenario")
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                }
                .font(.system(size: layout.buttonFont, weight: .semibold))
                .foregroundStyle(PokerTheme.background)
                .frame(maxWidth: .infinity)
                .frame(height: layout.buttonHeight)
                .background(PokerTheme.gold, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(CasinoButtonStyle())
            .accessibilityIdentifier("practice.next")
            .accessibilityHint("Loads another flop and keeps your score.")
        }
        .padding(layout.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PokerTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(tint.opacity(0.5), lineWidth: 1))
    }

    private func topicAccuracy(_ feedback: PracticeFeedback, layout: PracticeLayout) -> some View {
        let statistics = model.learningProgress.statistics(for: feedback.topic)
        return Text("\(feedback.topic.title) · \(statistics.correct)/\(statistics.attempts) correct")
            .font(.system(size: layout.captionFont, weight: .semibold).monospacedDigit())
            .foregroundStyle(PokerTheme.gold)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .accessibilityIdentifier("practice.topic")
    }

    private func resultMetric(_ title: String, value: String, identifier: String, layout: PracticeLayout) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: layout.captionFont))
                .foregroundStyle(PokerTheme.muted)
            Text(value)
                .font(.system(size: layout.bodyFont, weight: .semibold).monospacedDigit())
                .foregroundStyle(PokerTheme.text)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title == "SPR" ? "Stack-to-pot ratio" : "Board texture"): \(value)")
        .accessibilityIdentifier(identifier)
    }

    private func unavailablePanel(_ message: String, layout: PracticeLayout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Drill unavailable", systemImage: "exclamationmark.circle")
                .font(.system(size: layout.bodyFont, weight: .semibold))
                .foregroundStyle(PokerTheme.gold)
            Text(message)
                .font(.system(size: layout.bodyFont))
                .foregroundStyle(PokerTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(layout.panelPadding)
    }

    private func choiceColor(_ choice: PracticeChoice) -> Color {
        switch choice {
        case .bet, .raise: PokerTheme.green
        case .check: PokerTheme.text
        case .call: PokerTheme.gold
        case .fold: PokerTheme.red
        }
    }

    private func isAggressive(_ choice: PracticeChoice) -> Bool {
        choice == .bet || choice == .raise
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

    private func actionDescription(_ action: PokerAction, choice: PracticeChoice, pot: Double) -> String {
        switch action {
        case .bet(let amount): "Bet \(PokerFormat.chips(amount)) chips · \(PokerFormat.percent(amount / pot)) pot"
        case .allIn(let amount): "\(choice.title) all in · \(PokerFormat.chips(amount)) chips"
        case .check: "Check"
        case .fold: "Fold"
        case .call(let amount): "Call \(PokerFormat.chips(amount)) chips"
        case .raise(let amount): "Raise to \(PokerFormat.chips(amount)) chips"
        case .noAction: "No action"
        }
    }

    private enum PracticeFocus: Hashable { case progress, result }
}

/// Size the assets, not the entire interface, so controls retain real hit areas.
private struct PracticeLayout {
    let isLandscape: Bool
    let outerPadding: CGFloat
    let panelPadding: CGFloat
    let gap: CGFloat
    let sectionGap: CGFloat
    let feedbackGap: CGFloat
    let contentWidth: CGFloat
    let bodyHeight: CGFloat
    let headerHeight: CGFloat
    let cardHeight: CGFloat
    let titleFont: CGFloat
    let questionFont: CGFloat
    let resultFont: CGFloat
    let bodyFont: CGFloat
    let captionFont: CGFloat
    let metricFont: CGFloat
    let buttonFont: CGFloat
    let buttonHeight: CGFloat

    init(size: CGSize, typeSize: DynamicTypeSize) {
        isLandscape = size.width > size.height
        let compact = isLandscape || size.height < 620
        // Preserve a little text growth while honoring the single-screen layout.
        let textGrowth: CGFloat = typeSize >= .xLarge ? (isLandscape ? 1.04 : 1.08) : 1
        outerPadding = compact ? 10 : 16
        panelPadding = isLandscape ? 8 : (compact ? 10 : 14)
        gap = compact ? 8 : 12
        sectionGap = compact ? 8 : 12
        feedbackGap = isLandscape ? 4 : (compact ? 6 : 10)
        headerHeight = compact ? 28 : 36
        contentWidth = max(1, size.width - outerPadding * 2)
        bodyHeight = max(1, size.height - outerPadding * 2 - headerHeight - gap)
        cardHeight = compact ? 68 : 90
        titleFont = compact ? 21 : 27
        questionFont = compact ? 22 : 30
        resultFont = compact ? 19 : 26
        bodyFont = (isLandscape ? 12.5 : (compact ? 13 : 15)) * textGrowth
        captionFont = (compact ? 10.5 : 12) * textGrowth
        metricFont = (compact ? 17 : 22) * textGrowth
        buttonFont = (compact ? 15 : 17) * textGrowth
        buttonHeight = compact ? 44 : 52
    }
}
#endif
