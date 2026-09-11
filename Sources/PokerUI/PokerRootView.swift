#if os(iOS)
import SwiftUI
import PokerCore

/// Owns the practice session independently of the persisted live table.
@MainActor public struct PokerRootView: View {
    private let session: PokerSession
    @State private var practice: PracticeViewModel

    public init(session: PokerSession, practiceSeed: UInt64? = nil) {
        self.session = session
        _practice = State(initialValue: practiceSeed.map { PracticeViewModel(seed: $0) } ?? PracticeViewModel())
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
