import XCTest

@MainActor
final class PokerAssistantUITests: XCTestCase {
    private var app: XCUIApplication!

    private func prepareApp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = deterministicArguments(resetState: true)
    }

    func testFlopDrawUpdatesAdviceAndRejectsInvalidInput() {
        prepareApp()
        app.launch()

        openCardSelector(slot: "card.hole.0")
        pickCard(suit: "hearts", rank: 14)

        let usedAce = app.buttons["selector.rank.14"]
        XCTAssertTrue(usedAce.waitForExistence(timeout: 3))
        XCTAssertFalse(usedAce.isEnabled, "The already-selected ace of hearts must be unavailable in the second slot")

        pickCard(suit: "hearts", rank: 7)
        XCTAssertTrue(app.buttons["selector.done"].waitForNonExistence(timeout: 3))

        openCardSelector(slot: "card.flop.0")
        pickCard(suit: "hearts", rank: 13)
        pickCard(suit: "hearts", rank: 2)
        pickCard(suit: "clubs", rank: 9)
        XCTAssertTrue(app.buttons["selector.done"].waitForNonExistence(timeout: 3))

        replaceText(in: "input.pot", with: "150")
        replaceText(in: "input.call", with: "50")
        dismissNumberPad()

        assertLabel("FOLD", for: "action.title")
        assertLabel(containing: "9", for: "stats.outs")
        assertLabel(containing: "36", for: "stats.drawChance")
        assertLabel(containing: "25", for: "stats.potOdds")

        replaceText(in: "input.pot", with: "")
        assertLabel("CHECK INPUT", for: "action.title")
        XCTAssertNotEqual(app.staticTexts["action.title"].label, "FOLD", "Invalid input must clear stale advice")

        replaceText(in: "input.pot", with: "150")
        dismissNumberPad()
        assertLabel("FOLD", for: "action.title")

        let dashboard = app.scrollViews["dashboard.scroll"]
        XCTAssertTrue(scrollIntoView(app.staticTexts["action.title"], in: dashboard))
        attachScreenshot(named: "flop-recommendation")

        XCTAssertTrue(scrollIntoView(app.buttons["card.flop.0"], in: dashboard))
        attachScreenshot(named: "flop-cards")

        XCTAssertTrue(scrollIntoView(app.staticTexts["stats.outs"], in: dashboard))
        attachScreenshot(named: "flop-statistics")
    }

    func testSelectionSetupAndUndoPersistAcrossRelaunch() {
        prepareApp()
        app.launch()

        openCardSelector(slot: "card.hole.0")
        pickCard(suit: "spades", rank: 14)
        pickCard(suit: "diamonds", rank: 7)
        XCTAssertTrue(app.buttons["selector.done"].waitForNonExistence(timeout: 3))

        let firstSlot = app.buttons["card.hole.0"]
        let secondSlot = app.buttons["card.hole.1"]
        let savedFirstLabel = firstSlot.label
        let savedSecondLabel = secondSlot.label
        XCTAssertFalse(savedFirstLabel.isEmpty)
        XCTAssertFalse(savedSecondLabel.isEmpty)

        app.terminate()
        app.launchArguments = deterministicArguments(resetState: false)
        app.launch()

        assertLabel(savedFirstLabel, forButton: "card.hole.0")
        assertLabel(savedSecondLabel, forButton: "card.hole.1")

        let newHand = app.buttons["hand.new"]
        XCTAssertTrue(waitUntilHittable(newHand))
        newHand.tap()
        XCTAssertTrue(waitForLabelChange(of: app.buttons["card.hole.0"], from: savedFirstLabel))

        let undo = app.buttons["hand.undo"]
        XCTAssertTrue(waitUntilHittable(undo))
        undo.tap()
        assertLabel(savedFirstLabel, forButton: "card.hole.0")
        assertLabel(savedSecondLabel, forButton: "card.hole.1")

        openSetup()
        replaceText(in: "setup.bankroll", with: "2450")
        dismissNumberPad()

        let save = app.buttons["setup.save"]
        XCTAssertTrue(scrollIntoView(save, in: app))
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 3))

        openSetup()
        let bankroll = app.textFields["setup.bankroll"]
        XCTAssertTrue(scrollIntoView(bankroll, in: app))
        XCTAssertEqual(numericValue(bankroll.value), 2_450, accuracy: 0.001)
        app.buttons["setup.cancel"].tap()
    }

    func testAccessibilityTextKeepsSelectorAndSetupReachable() {
        prepareApp()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        attachScreenshot(named: "accessibility-xxxl-dashboard")

        let dashboard = app.scrollViews["dashboard.scroll"]
        let firstCard = app.buttons["card.hole.0"]
        XCTAssertTrue(scrollIntoView(firstCard, in: dashboard))
        firstCard.tap()

        let rankTwo = app.buttons["selector.rank.2"]
        XCTAssertTrue(scrollIntoView(rankTwo, in: app), "The rank grid must remain reachable at accessibility text sizes")
        attachScreenshot(named: "accessibility-xxxl-selector")

        let done = app.buttons["selector.done"]
        XCTAssertTrue(scrollIntoView(done, in: app), "The selector Done action must remain reachable")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 3))

        let setup = app.buttons["table.setup"]
        XCTAssertTrue(scrollIntoView(setup, in: dashboard))
        setup.tap()

        let minimumRaise = app.textFields["setup.minRaise"]
        XCTAssertTrue(scrollIntoView(minimumRaise, in: app), "The final setup field must be reachable by scrolling")

        let cancel = app.buttons["setup.cancel"]
        XCTAssertTrue(scrollIntoView(cancel, in: app), "The setup dismissal action must remain reachable")
        attachScreenshot(named: "accessibility-xxxl-setup")
        cancel.tap()
    }

    private func deterministicArguments(resetState: Bool) -> [String] {
        var arguments = [
            "--ui-testing",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        if resetState {
            arguments.append("--reset-state")
        }
        return arguments
    }

    private func openCardSelector(slot identifier: String) {
        let slot = app.buttons[identifier]
        XCTAssertTrue(scrollIntoView(slot, in: app.scrollViews["dashboard.scroll"]))
        slot.tap()
        XCTAssertTrue(app.buttons["selector.done"].waitForExistence(timeout: 3))
    }

    private func pickCard(suit: String, rank: Int) {
        let suitButton = app.buttons["selector.suit.\(suit)"]
        XCTAssertTrue(scrollIntoView(suitButton, in: app))
        suitButton.tap()

        let rankButton = app.buttons["selector.rank.\(rank)"]
        XCTAssertTrue(scrollIntoView(rankButton, in: app))
        XCTAssertTrue(rankButton.isEnabled, "Expected \(rank) of \(suit) to be available")
        rankButton.tap()
    }

    private func openSetup() {
        let setup = app.buttons["table.setup"]
        XCTAssertTrue(scrollIntoView(setup, in: app.scrollViews["dashboard.scroll"]))
        setup.tap()
        XCTAssertTrue(app.textFields["setup.bankroll"].waitForExistence(timeout: 3))
    }

    private func replaceText(in identifier: String, with replacement: String, container: XCUIElement? = nil) {
        let root: XCUIElement = container ?? app!
        let field = root.textFields[identifier]
        XCTAssertTrue(scrollIntoView(field, in: root))
        field.tap()

        let current = (field.value as? String) ?? ""
        if !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        if !replacement.isEmpty {
            field.typeText(replacement)
        }
    }

    private func dismissNumberPad() {
        let done = app.buttons["keyboard.done"]
        if done.waitForExistence(timeout: 1), done.isHittable {
            done.tap()
        }
    }

    @discardableResult
    private func scrollIntoView(_ element: XCUIElement, in container: XCUIElement) -> Bool {
        if waitUntilHittable(element, timeout: 1) { return true }

        for _ in 0..<8 {
            container.swipeUp()
            if waitUntilHittable(element, timeout: 0.5) { return true }
        }
        for _ in 0..<8 {
            container.swipeDown()
            if waitUntilHittable(element, timeout: 0.5) { return true }
        }
        return element.exists && element.isHittable
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        if element.exists && element.isHittable {
            return true
        }
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func assertLabel(_ expected: String, for identifier: String) {
        let element = app.staticTexts[identifier]
        XCTAssertTrue(scrollIntoView(element, in: app.scrollViews["dashboard.scroll"]))
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }

    private func assertLabel(containing fragment: String, for identifier: String) {
        let element = app.staticTexts[identifier]
        XCTAssertTrue(scrollIntoView(element, in: app.scrollViews["dashboard.scroll"]))
        let predicate = NSPredicate(format: "label CONTAINS %@", fragment)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }

    private func assertLabel(_ expected: String, forButton identifier: String) {
        let element = app.buttons[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }

    private func waitForLabelChange(of element: XCUIElement, from oldLabel: String) -> Bool {
        let predicate = NSPredicate(format: "label != %@", oldLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 3) == .completed
    }

    private func numericValue(_ value: Any?) -> Double {
        let numericText = String((value as? String ?? "").filter { $0.isNumber || $0 == "." })
        return Double(numericText) ?? .nan
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
