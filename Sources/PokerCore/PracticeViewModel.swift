import Observation

@MainActor @Observable
public final class PracticeViewModel {
    public private(set) var currentScenario: PracticeScenario?
    public private(set) var feedback: PracticeFeedback?
    public private(set) var errorMessage: String?
    public private(set) var correctCount = 0
    public private(set) var attemptCount = 0
    public private(set) var learningProgress: PracticeLearningProgress = .init()
    public private(set) var availableChoices: [PracticeChoice] = []

    private let scenarios: [PracticeScenario]?
    private var scenarioIndex = 0
    @ObservationIgnored private var generator: PracticeScenarioGenerator?
    @ObservationIgnored private var currentPrepared: PreparedPracticeScenario?
    @ObservationIgnored private let onProgressChange: ((PracticeLearningProgress) -> Void)?

    public convenience init(
        progress: PracticeLearningProgress = .init(),
        onProgressChange: ((PracticeLearningProgress) -> Void)? = nil
    ) {
        self.init(seed: UInt64.random(in: .min ... .max), progress: progress, onProgressChange: onProgressChange)
    }

    /// A repeatable stream from the real generator, useful for reproducible drills.
    public init(
        seed: UInt64, progress: PracticeLearningProgress = .init(),
        onProgressChange: ((PracticeLearningProgress) -> Void)? = nil
    ) {
        scenarios = nil
        generator = PracticeScenarioGenerator(seed: seed)
        learningProgress = progress.isValid ? progress : .init()
        self.onProgressChange = onProgressChange
        loadCurrentScenario()
    }

    public init(
        scenarios: [PracticeScenario], progress: PracticeLearningProgress = .init(),
        onProgressChange: ((PracticeLearningProgress) -> Void)? = nil
    ) {
        self.scenarios = scenarios
        learningProgress = progress.isValid ? progress : .init()
        self.onProgressChange = onProgressChange
        loadCurrentScenario()
    }

    public var scenarioNumber: Int { currentScenario == nil ? 0 : scenarioIndex + 1 }
    /// Nil means an unlimited generated stream; injected catalogs have a count.
    public var scenarioCount: Int? { scenarios?.count }
    public var canAnswer: Bool {
        currentScenario != nil && currentPrepared != nil && !availableChoices.isEmpty &&
            feedback == nil && errorMessage == nil
    }

    /// One accepted answer per presentation; choices never execute a wager.
    public func submit(_ choice: PracticeChoice) {
        guard canAnswer, availableChoices.contains(choice), let prepared = currentPrepared else { return }
        let isCorrect = choice == prepared.choice
        feedback = PracticeFeedback(
            scenarioID: prepared.scenario.id, chosenChoice: choice, correctChoice: prepared.choice,
            isCorrect: isCorrect, analysis: prepared.analysis,
            explanation: PracticeFeedbackBuilder.explanation(for: prepared), topic: prepared.topic
        )
        attemptCount += 1
        if isCorrect { correctCount += 1 }
        learningProgress.record(topic: prepared.topic, correct: isCorrect)
        onProgressChange?(learningProgress)
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
        currentPrepared = nil
        availableChoices = []
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
            } else if let generated = try generator?.next(progress: learningProgress) {
                prepared = generated
            } else {
                throw StrategyInputError.invalidBettingState(
                    "The practice generator is unavailable."
                )
            }
            currentPrepared = prepared
            availableChoices = prepared.availableChoices
            currentScenario = prepared.scenario
        } catch {
            errorMessage = "Practice scenario unavailable. \(error)"
        }
    }
}
