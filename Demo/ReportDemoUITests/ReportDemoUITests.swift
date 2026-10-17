import XCTest

final class ReportDemoUITests: XCTestCase {
    func testReportSheetOpensAndSends() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].tap()
        app.buttons["Report a problem"].tap()
        XCTAssertTrue(app.navigationBars["Report a problem"].waitForExistence(timeout: 5))
        let send = app.navigationBars.buttons["Send"]
        XCTAssertFalse(send.isEnabled, "Send needs a message")
        app.textFields.firstMatch.typeText("The list is empty\nExpected rows")
        XCTAssertTrue(app.switches["Include this screen"].exists, "screenshot captured")
        XCTAssertTrue(app.images["Screenshot to send"].exists)
        keep(app.screenshot())
        XCTAssertTrue(send.isEnabled)
        send.tap()
        // The simulator has no Mail account, so the share sheet opens with the files.
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10)
                      || app.navigationBars["UIActivityContentView"].waitForExistence(timeout: 5),
                      "share sheet never opened")
        keep(app.screenshot())
    }

    private func keep(_ shot: XCUIScreenshot) {
        let attachment = XCTAttachment(screenshot: shot)
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
