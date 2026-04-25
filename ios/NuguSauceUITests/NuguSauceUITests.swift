import XCTest

final class NuguSauceUITests: XCTestCase {
    func testLaunchShowsPrimaryTabs() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["홈"].exists)
        XCTAssertTrue(app.tabBars.buttons["검색"].exists)
        XCTAssertTrue(app.tabBars.buttons["등록"].exists)
        XCTAssertTrue(app.tabBars.buttons["프로필"].exists)
    }
}
