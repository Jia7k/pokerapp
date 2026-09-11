import Foundation
import Observation
import PokerCore

@MainActor protocol SessionStorage: AnyObject {
    func load() -> Data?
    func save(_ data: Data)
}

@MainActor private final class DefaultsSessionStorage: SessionStorage {
    private let defaults: UserDefaults
    private let key = "riverline.session.v1"
    init(defaults: UserDefaults) { self.defaults = defaults }
    func load() -> Data? { defaults.data(forKey: key) }
    func save(_ data: Data) { defaults.set(data, forKey: key) }
}

struct SessionSnapshot: Codable {
    var version = 1
    var configuration: TableConfiguration
    var position: String
    var situation: String
    var isPreflopAggressor: Bool
    var holeCards: [Card?]
    var boardCards: [Card?]

    @MainActor init(model: PokerViewModel) throws {
        configuration = TableConfiguration(bankroll: model.bankroll, betting: model.betting)
        try configuration.validate()
        position = model.position.rawValue
        situation = model.preflopSituation.rawValue
        isPreflopAggressor = model.isPreflopAggressor
        holeCards = model.holeCards
        boardCards = model.boardCards
    }

    @MainActor func makeModel() throws -> PokerViewModel {
        guard version == 1, holeCards.count == 2, boardCards.count == 5,
              let position = Position(rawValue: position),
              let situation = PreflopSituation(rawValue: situation) else {
            throw StrategyInputError.invalidCardSlot
        }
        try configuration.validate()
        let model = PokerViewModel(
            bankroll: configuration.bankroll, betting: configuration.betting,
            position: position, preflopSituation: situation, isPreflopAggressor: isPreflopAggressor
        )
        try restoreCards(hole: holeCards, board: boardCards, into: model)
        return model
    }
}

@MainActor private func restoreCards(hole: [Card?], board: [Card?], into model: PokerViewModel) throws {
    for (index, card) in hole.enumerated() {
        if let card { try model.setCard(card, at: .hole(index)) }
    }
    for (index, card) in board.enumerated() {
        if let card {
            let slot: CardSlot = index < 3 ? .flop(index) : (index == 3 ? .turn : .river)
            try model.setCard(card, at: slot)
        }
    }
}

@MainActor @Observable
public final class PokerSession {
    public private(set) var model: PokerViewModel
    public private(set) var potText: String
    public private(set) var callText: String
    public private(set) var canUndoNewHand = false
    @ObservationIgnored private let storage: any SessionStorage
    @ObservationIgnored private var undoSnapshot: SessionSnapshot?

    public convenience init(defaults: UserDefaults = .standard) {
        self.init(storage: DefaultsSessionStorage(defaults: defaults))
    }

    init(storage: any SessionStorage) {
        self.storage = storage
        let restored = storage.load().flatMap { data in
            try? JSONDecoder().decode(SessionSnapshot.self, from: data).makeModel()
        }
        let initial = restored ?? PokerViewModel(betting: BettingState(pot: 15, amountToCall: 10, opponentStack: 990))
        model = initial
        potText = PokerFormat.editable(initial.betting.pot)
        callText = PokerFormat.editable(initial.betting.amountToCall)
    }

    public var configuration: TableConfiguration {
        TableConfiguration(bankroll: model.bankroll, betting: model.betting)
    }
    public func updatePot(_ text: String) {
        potText = text
        model.betting.pot = PokerFormat.parseChips(text) ?? .nan
        save()
    }
    public func updateCall(_ text: String) {
        callText = text
        model.betting.amountToCall = PokerFormat.parseChips(text) ?? .nan
        save()
    }
    public func applyConfiguration(_ configuration: TableConfiguration) throws {
        try configuration.validate()
        let updated = PokerViewModel(
            bankroll: configuration.bankroll, betting: configuration.betting,
            position: model.position, preflopSituation: model.preflopSituation,
            isPreflopAggressor: model.isPreflopAggressor
        )
        try restoreCards(hole: model.holeCards, board: model.boardCards, into: updated)
        model = updated
        syncText()
        save()
    }
    public func setPosition(_ position: Position) { model.position = position; save() }
    public func setSituation(_ situation: PreflopSituation) { model.preflopSituation = situation; save() }
    public func setAggressor(_ isAggressor: Bool) { model.isPreflopAggressor = isAggressor; save() }
    public func newHand() {
        undoSnapshot = try? SessionSnapshot(model: model)
        canUndoNewHand = undoSnapshot != nil
        model.resetHand()
        syncText()
        save()
    }
    public func undoNewHand() {
        guard let restored = try? undoSnapshot?.makeModel() else { return }
        model = restored
        undoSnapshot = nil
        canUndoNewHand = false
        syncText()
        save()
    }
    public func save() {
        // Invalid text must clear advice without replacing the last valid disk snapshot.
        guard let snapshot = try? SessionSnapshot(model: model),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        storage.save(data)
    }

    private func syncText() {
        potText = PokerFormat.editable(model.betting.pot)
        callText = PokerFormat.editable(model.betting.amountToCall)
    }
}
