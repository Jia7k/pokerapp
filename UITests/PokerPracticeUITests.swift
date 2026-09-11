import XCTest

@MainActor
final class PokerPracticeUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launchPractice(accessibilityText: Bool = false, resetState: Bool = true, seed: UInt64 = 16) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--practice-seed", String(seed),
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ]
        if resetState { app.launchArguments.append("--reset-state") }
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
        XCTAssertFalse(offeredChoiceIDs.isEmpty)
    }

    func testGradingNextAndScoreRetention() {
        launchPractice()
        XCTAssertEqual(element("practice.score").label, "Correct: 0/0")
        XCTAssertTrue(element("practice.hole.0").label.contains("Queen of spades"))
        XCTAssertTrue(element("practice.hole.1").label.contains("Queen of diamonds"))
        XCTAssertFalse(element("practice.result").exists)
        XCTAssertFalse(element("practice.texture").exists)
        XCTAssertFalse(element("practice.spr").exists)
        assertQuestionFits()
        attachScreenshot(named: "practice-16pro-question")

        for id in offeredChoiceIDs {
            assertFullyVisible(app.buttons[id])
        }
        attachScreenshot(named: "practice-16pro-choices")
        // Seed 16 starts with a set of queens, checked to in an 80-chip pot.
        tapPracticeButton("practice.bet")
        assertPracticeLabel("CORRECT", id: "practice.result")
        assertPracticeLabel("Correct: 1/1", id: "practice.score")
        XCTAssertFalse(app.buttons["practice.bet"].exists)
        XCTAssertFalse(app.buttons["practice.check"].exists)
        XCTAssertFalse(app.buttons["practice.fold"].exists)
        XCTAssertFalse(app.buttons["practice.call"].exists)
        XCTAssertFalse(app.buttons["practice.raise"].exists)
        assertFullyVisible(element("practice.explanation"))
        XCTAssertFalse(element("practice.explanation").label.isEmpty)
        assertFullyVisible(element("practice.spr"))
        attachScreenshot(named: "practice-16pro-correct")

        tapPracticeButton("practice.next")
        XCTAssertFalse(element("practice.result").exists)
        XCTAssertFalse(element("practice.texture").exists)
        assertPracticeLabel("Correct: 1/1", id: "practice.score")

        // The next generated drill is a dry-board continuation bet; Check disagrees with the rule.
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
        tapPracticeButton(offeredChoiceIDs[0])
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
        var topics = Set<String>()
        var sawFacingBet = false
        var correctAnswers = 0
        for index in 0..<12 {
            assertPracticeLabel("Flop", id: "practice.progress")
            let deal = ["practice.hole.0", "practice.hole.1", "practice.flop.0",
                        "practice.flop.1", "practice.flop.2"].map { element($0).label }.joined(separator: "|")
            XCTAssertTrue(deals.insert(deal).inserted, "Seeded generated deals must not loop through the old catalog")
            pots.insert(element("practice.pot").label)
            assertQuestionFits()
            if index == 0 { attachScreenshot(named: "practice-16pro-accessibility-choices") }
            let choices = offeredChoiceIDs
            if app.buttons["practice.call"].exists { sawFacingBet = true }
            tapPracticeButton(index == 3 ? "practice.call" : choices[index % choices.count])
            assertFeedbackFits()
            if index == 3 {
                XCTAssertEqual(element("practice.result").label, "CORRECT")
                XCTAssertTrue(element("practice.recommendation").label.contains("Call 112.5"))
                attachScreenshot(named: "practice-16pro-call-feedback")
            }
            if index == 5 {
                XCTAssertEqual(element("practice.result").label, "CORRECT")
                XCTAssertTrue(element("practice.recommendation").label.contains("Call all in"))
                attachScreenshot(named: "practice-16pro-all-in-call")
            }
            let topic = element("practice.topic").label.components(separatedBy: " · ")[0]
            topics.insert(topic)
            if element("practice.result").label == "CORRECT" { correctAnswers += 1 }
            if index == 0 { attachScreenshot(named: "practice-16pro-accessibility-feedback") }
            if topic == "Value betting" { attachScreenshot(named: "practice-16pro-value-bet") }
            if topic == "Draw pricing" {
                attachScreenshot(named: "practice-16pro-draw-feedback")
            }
            tapPracticeButton("practice.next")
        }
        XCTAssertEqual(element("practice.progress").label, "Flop")
        XCTAssertEqual(element("practice.score").label, "Correct: \(correctAnswers)/12")
        XCTAssertGreaterThan(pots.count, 1)
        XCTAssertTrue(sawFacingBet)
        XCTAssertEqual(topics, Set(["Continuation bets", "Checking", "Short stacks", "Value betting", "Draw pricing", "Facing bets"]))
    }

    func testLandscapeQuestionAndFeedbackFitWithoutScrolling() {
        launchPractice(accessibilityText: true, seed: 33)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let landscape = NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: landscape, object: app)], timeout: 5), .completed)
        assertQuestionFits()
        attachScreenshot(named: "practice-16pro-landscape-question")
        tapPracticeButton("practice.call")
        assertPracticeLabel("CORRECT", id: "practice.result")
        XCTAssertTrue(element("practice.explanation").label.contains("Rule of 4"))
        assertFeedbackFits()
        attachScreenshot(named: "practice-16pro-landscape-feedback")
        tapPracticeButton("practice.next")
        assertQuestionFits()
    }

    func testAllInRaiseIsOfferedAndGradedAsRaise() {
        launchPractice(accessibilityText: true, seed: 1)
        XCTAssertEqual(offeredChoiceIDs, ["practice.fold", "practice.call", "practice.raise"])
        assertQuestionFits()
        attachScreenshot(named: "practice-16pro-raise-question")
        tapPracticeButton("practice.raise")
        assertPracticeLabel("CORRECT", id: "practice.result")
        XCTAssertTrue(element("practice.recommendation").label.contains("Raise all in"))
        XCTAssertTrue(element("practice.explanation").label.contains("300/750 = 0.4"))
        assertFeedbackFits()
        attachScreenshot(named: "practice-16pro-all-in-raise")
    }

    func testTopicAccuracySurvivesRelaunchWithAFreshSessionScore() {
        launchPractice()
        tapPracticeButton(offeredChoiceIDs[0])
        let savedTopic = element("practice.topic").label.components(separatedBy: " · ")[0]
        XCTAssertTrue(element("practice.topic").label.hasSuffix("/1 correct"))
        app.terminate()
        launchPractice(resetState: false)
        assertPracticeLabel("Correct: 0/0", id: "practice.score")
        for _ in 0..<9 {
            tapPracticeButton(offeredChoiceIDs[0])
            let label = element("practice.topic").label
            if label.hasPrefix(savedTopic + " · ") {
                XCTAssertTrue(label.hasSuffix("/2 correct"), "Saved topic accuracy must survive relaunch: \(label)")
                return
            }
            tapPracticeButton("practice.next")
        }
        XCTFail("The balanced round did not revisit the saved topic")
    }

    private var offeredChoiceIDs: [String] {
        ["practice.check", "practice.bet", "practice.fold", "practice.call", "practice.raise"]
            .filter { app.buttons[$0].exists }
    }

    private func assertQuestionFits() {
        XCTAssertEqual(app.scrollViews.count, 0, "Practice must fit without a scroll view")
        for id in ["practice.score", "practice.progress", "practice.hole.0", "practice.hole.1",
                   "practice.flop.0", "practice.flop.1", "practice.flop.2", "practice.pot",
                   "practice.effectiveStack", "practice.toCall", "practice.aggressor"] {
            assertFullyVisible(element(id))
        }
        let choices = offeredChoiceIDs
        XCTAssertGreaterThanOrEqual(choices.count, 2)
        for id in choices { assertFullyVisible(app.buttons[id]) }
        if app.buttons["practice.call"].exists {
            XCTAssertTrue(app.buttons["practice.fold"].exists)
            XCTAssertFalse(app.buttons["practice.check"].exists)
            XCTAssertFalse(app.buttons["practice.bet"].exists)
        } else {
            XCTAssertTrue(app.buttons["practice.check"].exists)
            XCTAssertFalse(app.buttons["practice.fold"].exists)
            XCTAssertFalse(app.buttons["practice.raise"].exists)
        }
        XCTAssertFalse(element("practice.texture").exists)
        XCTAssertFalse(element("practice.spr").exists)
        XCTAssertFalse(element("practice.topic").exists)
    }

    private func assertFeedbackFits() {
        XCTAssertEqual(app.scrollViews.count, 0)
        for id in ["practice.hole.0", "practice.hole.1", "practice.flop.0", "practice.flop.1",
                   "practice.flop.2", "practice.pot", "practice.effectiveStack", "practice.toCall",
                   "practice.aggressor", "practice.result", "practice.recommendation", "practice.explanation", "practice.texture",
                   "practice.spr", "practice.topic", "practice.next"] {
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
