import Observation

@MainActor @Observable
public final class PracticeViewModel {
    public private(set) var currentScenario: PracticeScenario?
    public private(set) var feedback: PracticeFeedback?
    public private(set) var errorMessage: String?
    public private(set) var correctCount = 0
    public private(set) var attemptCount = 0

    private let scenarios: [PracticeScenario]?
    private var scenarioIndex = 0
    @ObservationIgnored private var generator: PracticeScenarioGenerator?
    @ObservationIgnored private var currentAnalysis: PostflopAnalysis?
    @ObservationIgnored private var correctChoice: PracticeChoice?

    public convenience init() {
        self.init(seed: UInt64.random(in: .min ... .max))
    }

    /// A repeatable stream from the real generator, useful for reproducible drills.
    public init(seed: UInt64) {
        scenarios = nil
        generator = PracticeScenarioGenerator(seed: seed)
        loadCurrentScenario()
    }

    public init(scenarios: [PracticeScenario]) {
        self.scenarios = scenarios
        loadCurrentScenario()
    }

    public var scenarioNumber: Int { currentScenario == nil ? 0 : scenarioIndex + 1 }
    /// Nil means an unlimited generated stream; injected catalogs have a count.
    public var scenarioCount: Int? { scenarios?.count }
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
        guard feedback != nil else { return }
        if let scenarios {
            guard !scenarios.isEmpty else { return }
            scenarioIndex = scenarioIndex + 1 == scenarios.count ? 0 : scenarioIndex + 1
        } else {
            scenarioIndex += 1
        }
        loadCurrentScenario()
    }

    private func loadCurrentScenario() {
        // Clear first so an invalid next scenario cannot retain an earlier answer.
        currentScenario = nil
        currentAnalysis = nil
        correctChoice = nil
        feedback = nil
        errorMessage = nil

        do {
            let prepared: PreparedPracticeScenario
            if let scenarios {
                guard !scenarios.isEmpty else {
                    errorMessage = "No practice scenarios are available."
                    return
                }
                prepared = try PreparedPracticeScenario(scenarios[scenarioIndex])
            } else if let generated = try generator?.next() {
                prepared = generated
            } else {
                throw StrategyInputError.invalidBettingState(
                    "The practice generator is unavailable."
                )
            }
            currentAnalysis = prepared.analysis
            correctChoice = prepared.choice
            currentScenario = prepared.scenario
        } catch {
            errorMessage = "Practice scenario unavailable. \(error)"
        }
    }
}
