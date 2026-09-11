import XCTest

@MainActor
final class PokerPracticeUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launchPractice(accessibilityText: Bool = false) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--reset-state",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ]
        if accessibilityText {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        app.launch()
        let practiceTab = app.tabBars.buttons["Practice"]
        XCTAssertTrue(practiceTab.waitForExistence(timeout: 4))
        practiceTab.tap()
        XCTAssertTrue(element("practice.score").waitForExistence(timeout: 3))
    }

    func testGradingNextAndScoreRetention() {
        launchPractice()
        XCTAssertEqual(element("practice.score").label, "Correct: 0/0")
        XCTAssertTrue(element("practice.hole.0").label.contains("King of spades"))
        XCTAssertTrue(element("practice.hole.1").label.contains("Queen of spades"))
        XCTAssertFalse(element("practice.result").exists)
        XCTAssertFalse(element("practice.texture").exists)
        XCTAssertFalse(element("practice.spr").exists)
        attachScreenshot(named: "practice-question")

        for id in ["practice.bet", "practice.check", "practice.fold"] {
            XCTAssertTrue(scrollIntoView(app.buttons[id]))
        }
        attachScreenshot(named: "practice-choices")
        tapPracticeButton("practice.bet")
        assertPracticeLabel("CORRECT", id: "practice.result")
        assertPracticeLabel("Correct: 1/1", id: "practice.score")
        XCTAssertFalse(app.buttons["practice.bet"].exists)
        XCTAssertFalse(app.buttons["practice.check"].exists)
        XCTAssertFalse(app.buttons["practice.fold"].exists)
        XCTAssertTrue(scrollIntoView(element("practice.explanation")))
        XCTAssertFalse(element("practice.explanation").label.isEmpty)
        XCTAssertTrue(scrollIntoView(element("practice.spr")))
        attachScreenshot(named: "practice-correct")

        tapPracticeButton("practice.next")
        XCTAssertFalse(element("practice.result").exists)
        XCTAssertFalse(element("practice.texture").exists)
        assertPracticeLabel("Correct: 1/1", id: "practice.score")

        // The second drill is a flopped straight; checking disagrees with the engine.
        tapPracticeButton("practice.check")
        assertPracticeLabel("INCORRECT", id: "practice.result")
        assertPracticeLabel("Correct: 1/2", id: "practice.score")
        XCTAssertTrue(scrollIntoView(app.buttons["practice.next"]))
        attachScreenshot(named: "practice-incorrect")

        app.tabBars.buttons["Table"].tap()
        XCTAssertTrue(app.scrollViews["dashboard.scroll"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Practice"].tap()
        assertPracticeLabel("Correct: 1/2", id: "practice.score")
        assertPracticeLabel("INCORRECT", id: "practice.result")
    }

    func testPracticeDoesNotReplaceLiveCards() {
        launchPractice()
        app.tabBars.buttons["Table"].tap()
        let dashboard = app.scrollViews["dashboard.scroll"]
        let firstCard = app.buttons["card.hole.0"]
        XCTAssertTrue(scrollIntoView(firstCard, in: dashboard))
        firstCard.tap()
        app.buttons["selector.suit.hearts"].tap()
        app.buttons["selector.rank.14"].tap()
        app.buttons["selector.suit.diamonds"].tap()
        app.buttons["selector.rank.7"].tap()
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        let firstLabel = firstCard.label
        let secondLabel = app.buttons["card.hole.1"].label
        XCTAssertTrue(firstLabel.contains("Ace of hearts"))
        XCTAssertTrue(secondLabel.contains("7 of diamonds"))

        app.tabBars.buttons["Practice"].tap()
        tapPracticeButton("practice.bet")
        tapPracticeButton("practice.next")
        app.tabBars.buttons["Table"].tap()
        XCTAssertTrue(scrollIntoView(firstCard, in: dashboard))
        XCTAssertEqual(firstCard.label, firstLabel)
        XCTAssertEqual(app.buttons["card.hole.1"].label, secondLabel)
    }

    func testAccessibilityTextKeepsAllChoicesAndNextReachable() {
        launchPractice(accessibilityText: true)
        for id in ["practice.bet", "practice.check", "practice.fold"] {
            XCTAssertTrue(scrollIntoView(app.buttons[id]), "\(id) must remain reachable at the largest text size")
        }
        attachScreenshot(named: "practice-accessibility-choices")
        tapPracticeButton("practice.bet")
        assertPracticeLabel("CORRECT", id: "practice.result")
        XCTAssertTrue(scrollIntoView(element("practice.explanation")))
        attachScreenshot(named: "practice-accessibility-feedback")
        tapPracticeButton("practice.next")
        XCTAssertFalse(element("practice.result").exists)
        XCTAssertTrue(scrollIntoView(app.buttons["practice.bet"]))
        assertPracticeLabel("Correct: 1/1", id: "practice.score")
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tapPracticeButton(_ id: String) {
        let button = app.buttons[id]
        XCTAssertTrue(scrollIntoView(button), "Expected \(id) to be reachable")
        button.tap()
    }

    private func assertPracticeLabel(_ expected: String, id: String) {
        let target = element(id)
        XCTAssertTrue(scrollIntoView(target))
        XCTAssertEqual(target.label, expected)
    }

    @discardableResult
    private func scrollIntoView(_ target: XCUIElement, in container: XCUIElement? = nil) -> Bool {
        let scroll = container ?? app.scrollViews["practice.scroll"]
        for _ in 0..<24 {
            let viewport = unobscuredViewport(of: scroll)
            let exists = target.exists
            let frame = exists ? target.frame : .zero
            if exists && target.isHittable {
                // A floating tab bar may leave the edge of a button tappable
                // while covering its label. Require the whole button above it.
                if target.elementType != .button ||
                    (frame.minY >= viewport.minY && frame.maxY <= viewport.maxY) {
                    return true
                }
            }

            // Full flicks skipped Fold between the choices and the long footer
            // at accessibility sizes. Move toward the observed frame and stop
            // the gesture before releasing to avoid inertial overshoot.
            let moveUp = !exists || frame.maxY > viewport.maxY
            let remaining = exists
                ? (moveUp ? frame.maxY - viewport.maxY : viewport.minY - frame.minY)
                : viewport.height
            let distance = min(viewport.height * 0.42, max(44, remaining + 12))
            let startY = moveUp ? viewport.maxY - 12 : viewport.minY + 12
            let endY = startY + (moveUp ? -distance : distance)
            let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            let start = origin.withOffset(CGVector(dx: scroll.frame.midX, dy: startY))
            let end = origin.withOffset(CGVector(dx: scroll.frame.midX, dy: endY))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        }
        return false
    }

    private func unobscuredViewport(of scroll: XCUIElement) -> CGRect {
        let frame = scroll.frame
        let tabBar = app.tabBars.firstMatch
        let bottom = tabBar.exists ? min(frame.maxY, tabBar.frame.minY) : frame.maxY
        return CGRect(x: frame.minX, y: frame.minY + 8, width: frame.width, height: max(1, bottom - frame.minY - 16))
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
