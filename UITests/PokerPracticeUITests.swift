import XCTest

@MainActor
final class PokerPracticeUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launchPractice(accessibilityText: Bool = false) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--reset-state", "--practice-seed", "16",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ]
        if accessibilityText {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        let practiceTab = app.tabBars.buttons["Practice"]
        XCTAssertTrue(practiceTab.waitForExistence(timeout: 4))
        practiceTab.tap()
        XCTAssertTrue(element("practice.score").waitForExistence(timeout: 3))
    }

    func testGradingNextAndScoreRetention() {
        launchPractice()
        XCTAssertEqual(element("practice.score").label, "Correct: 0/0")
        XCTAssertTrue(element("practice.hole.0").label.contains("Queen of spades"))
        XCTAssertTrue(element("practice.hole.1").label.contains("Jack of hearts"))
        XCTAssertFalse(element("practice.result").exists)
        XCTAssertFalse(element("practice.texture").exists)
        XCTAssertFalse(element("practice.spr").exists)
        assertQuestionFits()
        attachScreenshot(named: "practice-16pro-question")

        for id in ["practice.bet", "practice.check", "practice.fold"] {
            assertFullyVisible(app.buttons[id])
        }
        attachScreenshot(named: "practice-16pro-choices")
        // Seed 16 starts with Qs Jh on 8s Ad 7d, facing 40 into an 80-chip pot.
        tapPracticeButton("practice.fold")
        assertPracticeLabel("CORRECT", id: "practice.result")
        assertPracticeLabel("Correct: 1/1", id: "practice.score")
        XCTAssertFalse(app.buttons["practice.bet"].exists)
        XCTAssertFalse(app.buttons["practice.check"].exists)
        XCTAssertFalse(app.buttons["practice.fold"].exists)
        assertFullyVisible(element("practice.explanation"))
        XCTAssertFalse(element("practice.explanation").label.isEmpty)
        assertFullyVisible(element("practice.spr"))
        attachScreenshot(named: "practice-16pro-correct")

        tapPracticeButton("practice.next")
        XCTAssertFalse(element("practice.result").exists)
        XCTAssertFalse(element("practice.texture").exists)
        assertPracticeLabel("Correct: 1/1", id: "practice.score")

        // The next generated drill also faces a wager; Check is not a legal action.
        tapPracticeButton("practice.check")
        assertPracticeLabel("INCORRECT", id: "practice.result")
        assertPracticeLabel("Correct: 1/2", id: "practice.score")
        assertFeedbackFits()
        attachScreenshot(named: "practice-16pro-incorrect")

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

    func testRandomDrillsContinuePastTenWithoutScrollingAtLargestTextSize() {
        launchPractice(accessibilityText: true)
        var deals = Set<String>()
        var pots = Set<String>()
        var capturedFacingBet = false
        for index in 0..<12 {
            assertPracticeLabel("Flop", id: "practice.progress")
            let deal = ["practice.hole.0", "practice.hole.1", "practice.flop.0",
                        "practice.flop.1", "practice.flop.2"].map { element($0).label }.joined(separator: "|")
            XCTAssertTrue(deals.insert(deal).inserted, "Seeded generated deals must not loop through the old catalog")
            pots.insert(element("practice.pot").label)
            assertQuestionFits()
            if index == 0 { attachScreenshot(named: "practice-16pro-accessibility-choices") }
            // Also exercises the longest legality prefix on a facing-bet drill.
            tapPracticeButton("practice.bet")
            assertFeedbackFits()
            if index == 0 { attachScreenshot(named: "practice-16pro-accessibility-feedback") }
            if index == 8 { attachScreenshot(named: "practice-16pro-value-bet") }
            if !capturedFacingBet && element("practice.explanation").label.hasPrefix("A bet is already outstanding") {
                attachScreenshot(named: "practice-16pro-long-feedback")
                capturedFacingBet = true
            }
            tapPracticeButton("practice.next")
        }
        XCTAssertEqual(element("practice.progress").label, "Flop")
        XCTAssertEqual(element("practice.score").label, "Correct: 1/12")
        XCTAssertGreaterThan(pots.count, 1)
        XCTAssertTrue(capturedFacingBet)
    }

    func testLandscapeQuestionAndFeedbackFitWithoutScrolling() {
        launchPractice(accessibilityText: true)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let landscape = NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: landscape, object: app)], timeout: 5), .completed)
        assertQuestionFits()
        attachScreenshot(named: "practice-16pro-landscape-question")
        tapPracticeButton("practice.bet")
        assertFeedbackFits()
        attachScreenshot(named: "practice-16pro-landscape-feedback")
        tapPracticeButton("practice.next")
        assertQuestionFits()
    }

    private func assertQuestionFits() {
        XCTAssertEqual(app.scrollViews.count, 0, "Practice must fit without a scroll view")
        for id in ["practice.score", "practice.progress", "practice.hole.0", "practice.hole.1",
                   "practice.flop.0", "practice.flop.1", "practice.flop.2", "practice.pot",
                   "practice.effectiveStack", "practice.toCall", "practice.aggressor",
                   "practice.bet", "practice.check", "practice.fold"] {
            assertFullyVisible(element(id))
        }
        XCTAssertFalse(element("practice.texture").exists)
        XCTAssertFalse(element("practice.spr").exists)
    }

    private func assertFeedbackFits() {
        XCTAssertEqual(app.scrollViews.count, 0)
        for id in ["practice.hole.0", "practice.hole.1", "practice.flop.0", "practice.flop.1",
                   "practice.flop.2", "practice.pot", "practice.effectiveStack", "practice.toCall",
                   "practice.aggressor", "practice.result", "practice.recommendation", "practice.explanation", "practice.texture",
                   "practice.spr", "practice.next"] {
            assertFullyVisible(element(id))
        }
    }

    private func assertFullyVisible(_ target: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(target.exists || target.waitForExistence(timeout: 2), "Missing \(target.identifier)", file: file, line: line)
        guard target.exists else { return }
        let frame = target.frame
        let window = app.frame
        let tabBar = app.tabBars.firstMatch
        let bottom = tabBar.exists ? min(window.maxY, tabBar.frame.minY) : window.maxY
        let statusBar = app.statusBars.firstMatch
        let top = statusBar.exists ? max(window.minY, statusBar.frame.maxY) : window.minY
        XCTAssertGreaterThan(frame.width, 0, file: file, line: line)
        XCTAssertGreaterThan(frame.height, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minY, top - 1, "\(target.identifier) clips above the screen", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, bottom + 1, "\(target.identifier) extends under the tab bar", file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minX, window.minX - 1, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 1, file: file, line: line)
        XCTAssertTrue(target.isHittable, "\(target.identifier) is not accessible without scrolling", file: file, line: line)
        if target.elementType == .button {
            XCTAssertGreaterThanOrEqual(frame.height, 44, "Preserve a 44-point tap target", file: file, line: line)
        }
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tapPracticeButton(_ id: String) {
        let button = app.buttons[id]
        assertFullyVisible(button)
        button.tap()
    }

    private func assertPracticeLabel(_ expected: String, id: String) {
        let target = element(id)
        assertFullyVisible(target)
        XCTAssertEqual(target.label, expected)
    }

    @discardableResult
    private func scrollIntoView(_ target: XCUIElement, in scroll: XCUIElement) -> Bool {
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
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
