import Foundation
import SwiftUI
import PokerUI

@main
@MainActor
struct PokerAssistantApp: App {
    private static let uiTestSuiteName = "com.riverline.pokerassistant.uitests"

    @State private var session: PokerSession

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let defaults: UserDefaults

        if arguments.contains("--ui-testing") {
            guard let testDefaults = UserDefaults(suiteName: Self.uiTestSuiteName) else {
                preconditionFailure("Unable to create the isolated UI test defaults suite")
            }
            if arguments.contains("--reset-state") {
                testDefaults.removePersistentDomain(forName: Self.uiTestSuiteName)
            }
            defaults = testDefaults
        } else {
            defaults = .standard
        }

        _session = State(initialValue: PokerSession(defaults: defaults))
    }

    var body: some Scene {
        WindowGroup {
            PokerDashboardView(session: session)
                .preferredColorScheme(.dark)
        }
    }
}
