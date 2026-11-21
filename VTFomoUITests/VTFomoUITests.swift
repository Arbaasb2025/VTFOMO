import XCTest

final class VTFomoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStudentSavesEventAndOpensProfile() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-store"]
        app.launch()

        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = system.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 4) {
            allow.tap()
        }

        let start = app.buttons["openSignIn"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        let help = app.buttons["Sign-in help & demo accounts"]
        XCTAssertTrue(help.waitForExistence(timeout: 5))
        help.tap()

        let helpTitle = app.navigationBars["Sign-in help"]
        XCTAssertTrue(helpTitle.waitForExistence(timeout: 5))

        let student = app.buttons["demo.stu@vt.edu"]
        for _ in 0..<4 where !student.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(student.isHittable, "The Student demo button could not be tapped.")
        student.tap()

        XCTAssertTrue(
            helpTitle.waitForNonExistence(timeout: 5),
            "The sign-in help sheet stayed open after selecting Student."
        )

        let email = app.textFields["Email address"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        XCTAssertEqual(
            email.value as? String,
            "stu@vt.edu",
            "Selecting Student did not fill the expected email address."
        )

        let login = app.buttons["Log In"]
        let loginReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "exists == true AND enabled == true AND hittable == true"
            ),
            object: login
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [loginReady], timeout: 8),
            .completed,
            "The student email was filled, but Log In never became enabled and tappable."
        )
        login.tap()

        let location = system.alerts.buttons["Allow While Using App"]
        if location.waitForExistence(timeout: 5) {
            location.tap()
        }

        let tabs = app.tabBars
        let compact = tabs.buttons["Events"].exists
        if compact {
            tabs.buttons["Events"].tap()
        }

        let title = "Pritchard Pizza & Board Games"
        let event = app.buttons["eventRow." + title]
        XCTAssertTrue(event.waitForExistence(timeout: 10))
        event.tap()

        let save = app.buttons["Save this event"]
        let details = app.scrollViews
            .containing(.button, identifier: "Save this event")
            .firstMatch

        for _ in 0..<10 where !save.isHittable {
            details.swipeUp()
        }
        XCTAssertTrue(save.isHittable, "The Save this event button could not be tapped.")
        save.tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))

        if compact {
            tabs.buttons["Saved"].tap()
        } else {
            app.buttons["Done"].tap()
            app.buttons["openSaved"].tap()
        }

        let savedEvent = app.buttons["savedRow." + title]
        XCTAssertTrue(
            savedEvent.waitForExistence(timeout: 5),
            "The selected event did not appear in Saved."
        )

        if compact {
            tabs.buttons["Profile"].tap()
        } else {
            app.navigationBars["Saved"].buttons.element(boundBy: 0).tap()
            app.buttons["openProfile"].tap()
        }

        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
