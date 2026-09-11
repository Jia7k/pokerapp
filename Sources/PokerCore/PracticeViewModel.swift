import Observation

@MainActor @Observable
public final class PracticeViewModel {
    public private(set) var currentScenario: PracticeScenario?
    public private(set) var feedback: PracticeFeedback?
    public private(set) var errorMessage: String?
    public private(set) var correctCount = 0
    public private(set) var attemptCount = 0

    private let scenarios: [PracticeScenario]
    private var scenarioIndex = 0
    @ObservationIgnored private var currentAnalysis: PostflopAnalysis?
    @ObservationIgnored private var correctChoice: PracticeChoice?

    public init(scenarios: [PracticeScenario] = PracticeScenarioCatalog.faceCardDrills) {
        self.scenarios = scenarios
        loadCurrentScenario()
    }

    public var scenarioNumber: Int { currentScenario == nil ? 0 : scenarioIndex + 1 }
    public var scenarioCount: Int { scenarios.count }
    public var canAnswer: Bool {
        currentScenario != nil && currentAnalysis != nil && correctChoice != nil &&
            feedback == nil && errorMessage == nil
    }

    /// One accepted answer per presentation; choices never execute a wager.
    public func submit(_ choice: PracticeChoice) {
        guard canAnswer,
              let scenario = currentScenario,
              let analysis = currentAnalysis,
              let expected = correctChoice else { return }

        var explanation = analysis.recommendation.explanation
        if scenario.betting.amountToCall > 0 {
            switch choice {
            case .check:
                explanation = "You cannot check while facing an outstanding bet. " + explanation
            case .bet:
                explanation = "A bet is already outstanding; continuing requires a call or raise. " + explanation
            case .fold:
                break
            }
        }
        let isCorrect = choice == expected
        feedback = PracticeFeedback(
            scenarioID: scenario.id, chosenChoice: choice, correctChoice: expected,
            isCorrect: isCorrect, analysis: analysis, explanation: explanation
        )
        attemptCount += 1
        if isCorrect { correctCount += 1 }
    }

    public func nextScenario() {
        guard feedback != nil, !scenarios.isEmpty else { return }
        scenarioIndex = scenarioIndex + 1 == scenarios.count ? 0 : scenarioIndex + 1
        loadCurrentScenario()
    }

    private func loadCurrentScenario() {
        // Clear first so an invalid next scenario cannot retain an earlier answer.
        currentScenario = nil
        currentAnalysis = nil
        correctChoice = nil
        feedback = nil
        errorMessage = nil

        guard !scenarios.isEmpty else {
            errorMessage = "No practice scenarios are available."
            return
        }

        let scenario = scenarios[scenarioIndex]
        do {
            guard scenario.holeCards.count == 2, scenario.flop.count == 3 else {
                throw StrategyInputError.invalidBettingState(
                    "A flop drill needs exactly two hole cards and three community cards."
                )
            }
            _ = try Deck.remaining(excluding: scenario.holeCards + scenario.flop)
            try scenario.betting.validate()
            guard scenario.betting.pot > 0,
                  scenario.betting.heroStack > 0,
                  scenario.betting.effectiveStack > 0 else {
                throw StrategyInputError.invalidBettingState(
                    "A drill needs a positive pot and chips available in the effective stack."
                )
            }

            let analysis = try PostflopHeuristicEngine.analyze(
                holeCards: scenario.holeCards, board: scenario.flop,
                betting: scenario.betting,
                isPreflopAggressor: scenario.isPreflopAggressor
            )
            let mappedChoice: PracticeChoice
            switch (analysis.recommendation.action, scenario.betting.amountToCall == 0) {
            case (.bet, true), (.allIn, true):
                // An all-in is an opening Bet only when no wager is outstanding.
                mappedChoice = .bet
            case (.check, true):
                mappedChoice = .check
            case (.fold, false):
                mappedChoice = .fold
            default:
                throw StrategyInputError.invalidBettingState(
                    "This drill needs an action outside the Bet, Check and Fold choices."
                )
            }

            currentAnalysis = analysis
            correctChoice = mappedChoice
            currentScenario = scenario
        } catch {
            errorMessage = "Practice scenario unavailable. \(error)"
        }
    }
}
