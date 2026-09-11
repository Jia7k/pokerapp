import Foundation
import SwiftUI
import PokerUI

@main
@MainActor
struct PokerAssistantApp: App {
    private static let uiTestSuiteName = "com.riverline.pokerassistant.uitests"

    @State private var session: PokerSession
    private let practiceSeed: UInt64?
    private let practiceDefaults: UserDefaults

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let defaults: UserDefaults
        // UI tests replay the real generator; ordinary sessions use system randomness.
        if arguments.contains("--ui-testing"),
           let seedFlag = arguments.firstIndex(of: "--practice-seed"),
           arguments.indices.contains(seedFlag + 1) {
            practiceSeed = UInt64(arguments[seedFlag + 1])
        } else {
            practiceSeed = nil
        }

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

        practiceDefaults = defaults
        _session = State(initialValue: PokerSession(defaults: defaults))
    }

    var body: some Scene {
        WindowGroup {
            PokerRootView(session: session, practiceSeed: practiceSeed, practiceDefaults: practiceDefaults)
                .preferredColorScheme(.dark)
        }
    }
}
