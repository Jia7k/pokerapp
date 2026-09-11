public enum PracticeTopic: String, CaseIterable, Codable, Sendable {
    case continuationBet, checking, shortStack, valueBet, drawPrice, facingBet

    public var title: String {
        switch self {
        case .continuationBet: "Continuation bets"
        case .checking: "Checking"
        case .shortStack: "Short stacks"
        case .valueBet: "Value betting"
        case .drawPrice: "Draw pricing"
        case .facingBet: "Facing bets"
        }
    }
}

public struct PracticeTopicStats: Codable, Equatable, Sendable {
    public let attempts: Int
    public let correct: Int

    public init(attempts: Int = 0, correct: Int = 0) {
        self.attempts = attempts
        self.correct = correct
    }
}

/// A bounded record of learning by concept, independent of the session score.
public struct PracticeLearningProgress: Codable, Equatable, Sendable {
    public static let maximumStoredAttempts = 1_000_000
    public private(set) var stats: [PracticeTopic: PracticeTopicStats]

    public init(stats: [PracticeTopic: PracticeTopicStats] = [:]) {
        self.stats = stats
    }

    public var isValid: Bool {
        stats.values.allSatisfy {
            (0...Self.maximumStoredAttempts).contains($0.attempts) &&
                $0.correct >= 0 && $0.correct <= $0.attempts
        }
    }

    public func statistics(for topic: PracticeTopic) -> PracticeTopicStats {
        stats[topic] ?? PracticeTopicStats()
    }

    public mutating func record(topic: PracticeTopic, correct wasCorrect: Bool) {
        if !isValid { self = Self() }
        let previous = statistics(for: topic)
        // Halve old evidence before the bounded counter fills. This also lets
        // sufficiently old mistakes eventually stop affecting the review mix.
        let divisor = previous.attempts == Self.maximumStoredAttempts ? 2 : 1
        stats[topic] = PracticeTopicStats(
            attempts: previous.attempts / divisor + 1,
            correct: previous.correct / divisor + (wasCorrect ? 1 : 0)
        )
    }

    /// Bonus practice fades as the smoothed error rate falls below 20%.
    /// Every topic still receives the generator's regular coverage slot.
    public func reviewWeight(for topic: PracticeTopic) -> Double {
        guard isValid else { return 0 }
        let progress = statistics(for: topic)
        let misses = progress.attempts - progress.correct
        guard misses > 0 else { return 0 }
        let smoothedError = Double(misses + 1) / Double(progress.attempts + 2)
        return max(0, smoothedError - 0.20)
    }
}
