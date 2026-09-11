#if os(iOS)
import SwiftUI
import PokerCore

@MainActor
public struct PokerStatsView: View {
    private let analysis: PokerAnalysis

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsOutCards = false

    public init(analysis: PokerAnalysis) {
        self.analysis = analysis
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("TABLE READ")
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(PokerTheme.gold)

                Text("Odds & texture")
                    .font(.title2.bold())
                    .foregroundStyle(PokerTheme.text)
            }

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
                MetricView(
                    title: "Pot odds",
                    value: PokerFormat.percent(analysis.requiredEquity),
                    detail: "Required equity to call",
                    systemImage: "circle.lefthalf.filled",
                    identifier: "stats.potOdds",
                    tint: PokerTheme.gold
                )

                MetricView(
                    title: "Draw chance",
                    value: PokerFormat.percent(analysis.approximateDrawProbability),
                    detail: drawMetricDetail,
                    systemImage: "chart.line.uptrend.xyaxis",
                    identifier: "stats.drawChance",
                    tint: PokerTheme.green
                )

                MetricView(
                    title: "Potential outs",
                    value: outsValue,
                    detail: outsMetricDetail,
                    systemImage: "suit.spade.fill",
                    identifier: "stats.outs",
                    tint: PokerTheme.ivory
                )

                MetricView(
                    title: "SPR",
                    value: PokerFormat.ratio(analysis.stackToPotRatio),
                    detail: "Effective stack ÷ pot",
                    systemImage: "square.stack.3d.up",
                    identifier: "stats.spr",
                    tint: PokerTheme.gold
                )
            }

            if let probabilityDetail {
                Label {
                    Text(probabilityDetail)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "scope")
                        .foregroundStyle(PokerTheme.green)
                }
                .font(.caption)
                .foregroundStyle(PokerTheme.muted)
            }

            drawStateNote

            if let cards = analysis.outs?.cards, !cards.isEmpty {
                Divider().overlay(PokerTheme.border.opacity(0.7))

                DisclosureGroup(isExpanded: $showsOutCards) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 52), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(cards.sorted()) { card in
                            OutCardChip(card: card)
                        }
                    }
                    .padding(.top, 12)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.grid.3x2")
                            .foregroundStyle(PokerTheme.gold)
                        Text("Specific completion cards")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PokerTheme.text)
                    }
                    .frame(minHeight: 44)
                }
                .tint(PokerTheme.gold)
                .accessibilityHint("Shows the unique cards counted as potential outs")
            }

            if let texture = analysis.texture {
                Divider().overlay(PokerTheme.border.opacity(0.7))

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        textureBadge(texture)
                        if texture.isPaired { pairedBadge }
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        textureBadge(texture)
                        if texture.isPaired { pairedBadge }
                    }
                }
            }
        }
        .casinoPanel()
    }

    private var metricColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 12)]
        }
        return [
            GridItem(.flexible(minimum: 0), spacing: 12),
            GridItem(.flexible(minimum: 0), spacing: 12),
        ]
    }

    private var drawMetricDetail: String {
        switch analysis.street {
        case .flop: "Rule of 4 approximation"
        case .turn: "Rule of 2 approximation"
        case .preflop, .river, nil: "Completion estimate"
        }
    }

    private var outsValue: String {
        guard let outs = analysis.outs else { return "—" }
        guard outs.street != .river else { return "—" }
        return String(outs.count)
    }

    private var outsMetricDetail: String {
        guard let outs = analysis.outs else { return "Awaiting postflop cards" }
        if outs.street == .river { return "No future draw card" }
        if outs.count == 0 { return "No listed completion cards" }
        return "Unique made-hand completions"
    }

    private var probabilityDetail: String? {
        guard let outs = analysis.outs else { return nil }
        let nextCard = outs.nextCardCompletionProbability
        let decision = analysis.decisionDrawProbability

        if let decision, let nextCard,
           abs(decision - nextCard) > 0.000_001 {
            return "Call horizon \(PokerFormat.percent(decision)); exact next card \(PokerFormat.percent(nextCard)). Completion estimates, not win equity."
        }
        if let decision {
            return "Call horizon \(PokerFormat.percent(decision)); exact next-card completion estimate, not win equity."
        }
        if let nextCard {
            return "Exact next card \(PokerFormat.percent(nextCard)). Completion estimate, not win equity."
        }
        return nil
    }

    @ViewBuilder
    private var drawStateNote: some View {
        if analysis.status == .awaitingHoleCards || analysis.status == .awaitingFlop {
            explanatoryNote(
                icon: "rectangle.and.hand.point.up.left",
                text: analysis.message ?? "Add your cards to calculate draw information."
            )
        } else if analysis.status == .invalidInput {
            explanatoryNote(
                icon: "exclamationmark.triangle",
                text: "Draw information is unavailable until the input is valid."
            )
        } else if analysis.street == .preflop {
            explanatoryNote(icon: "clock", text: "Draw estimates begin after the flop is complete.")
        } else if analysis.street == .river {
            explanatoryNote(icon: "flag.checkered", text: "The river is complete; there is no future card for a draw estimate.")
        } else if let outs = analysis.outs, outs.count == 0 {
            explanatoryNote(
                icon: "minus.circle",
                text: "No listed made-hand completion cards are known. This does not mean zero chance to win."
            )
        } else {
            explanatoryNote(
                icon: "info.circle",
                text: "Completion estimate, not win equity. Opponent ranges are outside this calculation."
            )
        }
    }

    private func explanatoryNote(icon: String, text: String) -> some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(PokerTheme.gold)
        }
        .font(.caption)
        .foregroundStyle(PokerTheme.muted)
    }

    private func textureBadge(_ report: BoardTextureReport) -> some View {
        let label: String
        let icon: String
        switch report.texture {
        case .dryRainbow:
            (label, icon) = ("Dry · rainbow", "sun.max")
        case .wetConnected:
            (label, icon) = ("Wet / connected", "drop.triangle")
        case .monotone:
            (label, icon) = ("Monotone", "paintpalette")
        }
        return Label(label, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PokerTheme.text)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(PokerTheme.raised, in: Capsule())
            .accessibilityLabel("Board texture: \(label)")
    }

    private var pairedBadge: some View {
        Label("Paired board", systemImage: "equal.circle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(PokerTheme.text)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(PokerTheme.raised, in: Capsule())
    }
}

@MainActor
private struct MetricView: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let identifier: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PokerTheme.muted)

            Text(value)
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(value == "—" ? PokerTheme.muted : tint)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(PokerTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(14)
        .background(PokerTheme.raised.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PokerTheme.border.opacity(0.45), lineWidth: 1)
        }
    }
}

@MainActor
private struct OutCardChip: View {
    let card: Card

    var body: some View {
        Text(card.description)
            .font(.body.monospaced().weight(.bold))
            .foregroundStyle(cardColor)
            .frame(maxWidth: .infinity, minHeight: 36)
            .padding(.horizontal, 8)
            .background(PokerTheme.ivory, in: RoundedRectangle(cornerRadius: 9))
            .accessibilityLabel(PokerFormat.cardName(card))
    }

    private var cardColor: Color {
        switch card.suit {
        case .hearts, .diamonds: PokerTheme.cardRed
        case .spades, .clubs: PokerTheme.cardInk
        }
    }
}
#endif
