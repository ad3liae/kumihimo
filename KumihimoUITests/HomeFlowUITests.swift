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

    func testNewProjectCanBeNamedAndSaved() {
        let app = launch(arguments: ["--ui-testing-empty-projects"])

        element(in: app, identifier: "home.create-project").tap()
        app.navigationBars["新しい組紐"].buttons["保存"].tap()

        let nameField = app.textFields["作品名"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.typeText("夏の配色")
        app.navigationBars["作品を保存"].buttons["保存"].tap()

        XCTAssertTrue(app.navigationBars["夏の配色"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.navigationBars["夏の配色"].buttons["保存"].exists)
    }

    func testSavedProjectOpensEditorScreen() {
        let app = launch(arguments: ["--ui-testing-sample-projects"])

        element(in: app, identifier: firstProjectIdentifier).tap()

        XCTAssertTrue(app.navigationBars["丸源氏・青と白"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.navigationBars["丸源氏・青と白"].buttons["保存"].exists)
        XCTAssertTrue(app.staticTexts["色の配置"].exists)
    }

    func testThreadCountReductionDismissesConfirmation() {
        let app = launch(arguments: ["--ui-testing-new-editor"])
        let pickerIdentifier = "project-editor.thread-count-picker"

        selectThreadCount(8, in: app, pickerIdentifier: pickerIdentifier)
        selectThreadCount(4, in: app, pickerIdentifier: pickerIdentifier)

        let alert = app.alerts["糸の本数を減らしますか？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["減らす"].tap()

        let dismissed = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: alert
        )
        wait(for: [dismissed], timeout: 2)
        XCTAssertFalse(alert.waitForExistence(timeout: 1), "Reduction alert appeared again")
        XCTAssertEqual(
            element(in: app, identifier: pickerIdentifier).value as? String,
            "4本"
        )
    }

    func testCancellingThreadCountReductionDismissesConfirmation() {
        let app = launch(arguments: ["--ui-testing-new-editor"])
        let pickerIdentifier = "project-editor.thread-count-picker"

        selectThreadCount(8, in: app, pickerIdentifier: pickerIdentifier)
        selectThreadCount(4, in: app, pickerIdentifier: pickerIdentifier)

        let alert = app.alerts["糸の本数を減らしますか？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["キャンセル"].tap()

        let dismissed = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: alert
        )
        wait(for: [dismissed], timeout: 2)
        XCTAssertFalse(alert.waitForExistence(timeout: 1), "Reduction alert appeared again")
        XCTAssertEqual(
            element(in: app, identifier: pickerIdentifier).value as? String,
            "8本"
        )
    }

    func testSelectingThreadColorDismissesSheet() {
        let app = launch(arguments: ["--ui-testing-new-editor"])

        app.buttons["糸1、生成り"].tap()
        let colorSheet = app.navigationBars["糸1の色"]
        XCTAssertTrue(colorSheet.waitForExistence(timeout: 2))
        app.buttons["青、仮コードK-06"].tap()

        let dismissed = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: colorSheet
        )
        wait(for: [dismissed], timeout: 2)
    }

    func testSixteenThreadProjectOpensMaruGenji3DPreview() {
        let app = launch(arguments: ["--ui-testing-colorful-editor"])
        let show3DIdentifier = "project-editor.preset-maru-genji-16-show-3d"
        let show3DButton = app.descendants(matching: .any)[show3DIdentifier].firstMatch

        XCTAssertTrue(show3DButton.waitForExistence(timeout: 3))
        for _ in 0..<5 where !show3DButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(show3DButton.isHittable)
        show3DButton.tap()

        XCTAssertTrue(app.navigationBars["丸源氏・3D試作"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["左へ回転"].exists)
        XCTAssertTrue(app.buttons["正面に戻す"].exists)
        XCTAssertTrue(app.buttons["右へ回転"].exists)
        XCTAssertTrue(app.staticTexts["資料の手順をもとにした暫定シミュレーションです。"].exists)

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "maru-genji-3d-preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testFailedSimulationStillAllowsClearingSelectedPreset() {
        let app = launch(arguments: ["--ui-testing-selected-failed-editor"])

        assertUndecidedPresetCanBeSelected(in: app)
        XCTAssertTrue(app.staticTexts["完成イメージを生成できませんでした"].exists)
    }

    func testCalculatingSimulationStillAllowsClearingSelectedPreset() {
        let app = launch(arguments: ["--ui-testing-selected-calculating-editor"])

        assertUndecidedPresetCanBeSelected(in: app)
        XCTAssertTrue(app.staticTexts["完成イメージを計算中"].exists)
    }

    func testNoCompatiblePresetStillShowsUndecidedSelection() {
        let app = launch(arguments: ["--ui-testing-new-editor"])

        let undecided = element(
            in: app,
            identifier: "project-editor.preset-undecided",
            scrollingIfNeeded: true
        )
        XCTAssertEqual(undecided.value as? String, "選択中")
        undecided.tap()
        XCTAssertEqual(undecided.value as? String, "選択中")
        XCTAssertTrue(app.staticTexts["この本数の組み方はまだありません"].exists)
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

    private func element(
        in app: XCUIApplication,
        identifier: String,
        scrollingIfNeeded: Bool
    ) -> XCUIElement {
        let element = self.element(in: app, identifier: identifier)
        if scrollingIfNeeded {
            for _ in 0..<8 where !element.isHittable {
                app.swipeUp()
            }
        }
        XCTAssertTrue(element.isHittable, "Element is not hittable: \(identifier)")
        return element
    }

    private func assertUndecidedPresetCanBeSelected(in app: XCUIApplication) {
        let undecided = element(
            in: app,
            identifier: "project-editor.preset-undecided",
            scrollingIfNeeded: true
        )
        XCTAssertEqual(undecided.value as? String, "未選択")
        undecided.tap()
        XCTAssertEqual(undecided.value as? String, "選択中")
    }

    private func selectThreadCount(
        _ count: Int,
        in app: XCUIApplication,
        pickerIdentifier: String
    ) {
        element(in: app, identifier: pickerIdentifier).tap()
        app.buttons["\(count)本"].tap()
    }
}
