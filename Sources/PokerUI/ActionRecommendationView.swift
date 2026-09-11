#if os(iOS)
import SwiftUI
import PokerCore

@MainActor
public struct ActionRecommendationView: View {
    private let analysis: PokerAnalysis
    private let pot: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsReason = false
    @ScaledMetric(relativeTo: .largeTitle) private var actionFontSize: CGFloat = 56

    public init(analysis: PokerAnalysis, pot: Double) {
        self.analysis = analysis
        self.pot = pot
    }

    public var body: some View {
        let presentation = presentation

        VStack(alignment: .leading, spacing: 20) {
            if dynamicTypeSize.isAccessibilitySize {
                Text(PokerFormat.street(analysis.street).capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PokerTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Label("RECOMMENDED PLAY", systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(PokerTheme.gold)

                    Spacer(minLength: 12)

                    Text(PokerFormat.street(analysis.street))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PokerTheme.muted)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(presentation.title)
                    .font(dynamicTypeSize.isAccessibilitySize
                          ? .system(.largeTitle, design: .serif).weight(.black)
                          : .system(size: actionFontSize, weight: .black, design: .serif))
                    .foregroundStyle(presentation.accent)
                    .tracking(-1)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("action.title")

                if let amount = presentation.amount {
                    Text(amount)
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(PokerTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("action.amount")
                }

                if let amountMeaning = presentation.amountMeaning {
                    Text(amountMeaning)
                        .font(.caption)
                        .foregroundStyle(PokerTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(presentation.summary)
                .font(.body)
                .foregroundStyle(PokerTheme.text.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            if presentation.canExplain {
                Divider().overlay(PokerTheme.border.opacity(0.7))

                Button {
                    if reduceMotion {
                        showsReason.toggle()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsReason.toggle()
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "quote.bubble")
                            .foregroundStyle(PokerTheme.gold)
                        Text(showsReason ? "Hide reasoning" : "Why this play?")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PokerTheme.text)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PokerTheme.muted)
                            .rotationEffect(.degrees(showsReason ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                    .frame(minHeight: 44)
                }
                .buttonStyle(CasinoButtonStyle())
                .accessibilityIdentifier("action.reason")
                .accessibilityValue(showsReason ? "Expanded" : "Collapsed")

                if showsReason, let recommendation = analysis.recommendation {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(recommendation.explanation)
                            .font(.subheadline)
                            .foregroundStyle(PokerTheme.text)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(Array(recommendation.notes.enumerated()), id: \.offset) { _, note in
                            Label {
                                Text(note)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "diamond.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(PokerTheme.gold)
                            }
                            .font(.caption)
                            .foregroundStyle(PokerTheme.muted)
                        }
                    }
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .casinoPanel()
        .overlay {
            RoundedRectangle(cornerRadius: PokerTheme.radius)
                .fill(
                    LinearGradient(
                        colors: [PokerTheme.green.opacity(0.08), .clear, PokerTheme.gold.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        }
        .overlay(alignment: .leading) {
            Capsule()
                .fill(presentation.accent)
                .frame(width: 3)
                .padding(.vertical, 24)
                .allowsHitTesting(false)
        }
    }

    private var presentation: Presentation {
        switch analysis.status {
        case .awaitingHoleCards, .awaitingFlop:
            return Presentation(
                title: "ADD YOUR CARDS",
                summary: analysis.message ?? "Choose your cards to build a current recommendation.",
                accent: PokerTheme.gold
            )
        case .invalidInput:
            return Presentation(
                title: "CHECK INPUT",
                summary: analysis.message ?? "Review the table values and try again.",
                accent: PokerTheme.red
            )
        case .ready:
            guard let recommendation = analysis.recommendation else {
                return Presentation(
                    title: "ADD YOUR CARDS",
                    summary: analysis.message ?? "Complete the current card selection to get a recommendation.",
                    accent: PokerTheme.gold
                )
            }
            return presentation(for: recommendation)
        }
    }

    private func presentation(for recommendation: ActionRecommendation) -> Presentation {
        switch recommendation.action {
        case .noAction:
            return Presentation(
                title: "WAIT FOR BOARD",
                summary: recommendation.explanation,
                accent: PokerTheme.gold,
                canExplain: true
            )
        case .fold:
            return actionPresentation(
                title: "FOLD", accent: PokerTheme.red,
                recommendation: recommendation
            )
        case .check:
            return actionPresentation(
                title: "CHECK", accent: PokerTheme.gold,
                recommendation: recommendation
            )
        case .call(let amount):
            return actionPresentation(
                title: "CALL", amount: PokerFormat.chips(amount),
                amountMeaning: "Additional chips", accent: PokerTheme.gold,
                recommendation: recommendation
            )
        case .bet(let amount):
            let potFraction = pot.isFinite && pot > 0 && amount.isFinite
                ? amount / pot
                : nil
            let formattedAmount = potFraction?.isFinite == true
                ? "\(PokerFormat.chips(amount)) · \(PokerFormat.percent(potFraction)) pot"
                : PokerFormat.chips(amount)
            return actionPresentation(
                title: "BET", amount: formattedAmount,
                amountMeaning: "Additional chips · actual pot fraction", accent: PokerTheme.green,
                recommendation: recommendation
            )
        case .raise(let total):
            return actionPresentation(
                title: "RAISE", amount: "TO \(PokerFormat.chips(total))",
                amountMeaning: "Total street contribution", accent: PokerTheme.green,
                recommendation: recommendation
            )
        case .allIn(let amount):
            return actionPresentation(
                title: "ALL IN", amount: PokerFormat.chips(amount),
                amountMeaning: "Additional chips", accent: PokerTheme.green,
                recommendation: recommendation
            )
        }
    }

    private func actionPresentation(
        title: String,
        amount: String? = nil,
        amountMeaning: String? = nil,
        accent: Color,
        recommendation: ActionRecommendation
    ) -> Presentation {
        Presentation(
            title: title,
            amount: amount,
            amountMeaning: amountMeaning,
            summary: recommendation.explanation,
            accent: accent,
            canExplain: true
        )
    }
}

private struct Presentation {
    let title: String
    var amount: String? = nil
    var amountMeaning: String? = nil
    let summary: String
    let accent: Color
    var canExplain = false
}
#endif
