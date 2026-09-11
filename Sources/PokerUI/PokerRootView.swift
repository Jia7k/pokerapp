#if os(iOS)
import SwiftUI
import PokerCore
import Foundation

/// Owns the practice session independently of the persisted live table.
@MainActor public struct PokerRootView: View {
    private let session: PokerSession
    @State private var practice: PracticeViewModel

    public init(session: PokerSession, practiceSeed: UInt64? = nil, practiceDefaults: UserDefaults = .standard) {
        self.session = session
        let store = PracticeProgressStore(defaults: practiceDefaults)
        let progress = store.load()
        let practice: PracticeViewModel
        if let practiceSeed {
            practice = PracticeViewModel(seed: practiceSeed, progress: progress, onProgressChange: { store.save($0) })
        } else {
            practice = PracticeViewModel(progress: progress, onProgressChange: { store.save($0) })
        }
        _practice = State(initialValue: practice)
    }

    public var body: some View {
        TabView {
            PokerDashboardView(session: session)
                .tabItem { Label("Table", systemImage: "suit.spade.fill") }

            PracticeView(model: practice)
                .tabItem { Label("Practice", systemImage: "target") }
        }
        .tint(PokerTheme.gold)
        .preferredColorScheme(.dark)
    }
}
#endif
