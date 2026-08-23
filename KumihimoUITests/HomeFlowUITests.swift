import XCTest

@MainActor
final class HomeFlowUITests: XCTestCase {
    private let firstProjectIdentifier = "home.project.00000000-0000-0000-0000-000000000001"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEmptyStateOpensNewProjectScreen() {
        let app = launch(arguments: ["--ui-testing-empty-projects"])

        element(in: app, identifier: "home.create-project").tap()

        XCTAssertTrue(app.navigationBars["新しい組紐"].waitForExistence(timeout: 2))
    }

    func testSavedProjectOpensEditorScreen() {
        let app = launch(arguments: ["--ui-testing-sample-projects"])

        element(in: app, identifier: firstProjectIdentifier).tap()

        XCTAssertTrue(app.navigationBars["組紐を編集"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["作品ID: 00000000-0000-0000-0000-000000000001"].exists)
    }

    func testDeleteCanBeCancelledThenConfirmed() {
        let app = launch(arguments: ["--ui-testing-sample-projects"])
        var project = element(in: app, identifier: firstProjectIdentifier)

        project.swipeLeft()
        app.buttons["削除"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 2))
        app.alerts.firstMatch.buttons["キャンセル"].tap()
        XCTAssertTrue(project.exists)

        project = element(in: app, identifier: firstProjectIdentifier)
        project.swipeLeft()
        app.buttons["削除"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 2))
        app.alerts.firstMatch.buttons["削除"].tap()

        let removed = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: project
        )
        wait(for: [removed], timeout: 2)
    }

    private func launch(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 3), "Missing element: \(identifier)")
        return element
    }
}
