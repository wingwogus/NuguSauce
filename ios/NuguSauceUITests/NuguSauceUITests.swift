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

    func testSearchFlavorFilterPresentsSelectionSheet() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["검색"].tap()

        let flavorFilterButton = app.buttons["flavor-filter-button"]
        XCTAssertTrue(flavorFilterButton.waitForExistence(timeout: 5))

        flavorFilterButton.tap()

        XCTAssertTrue(app.staticTexts["원하는 맛을 골라 검색 결과를 좁혀보세요."].waitForExistence(timeout: 5))
    }

    func testSearchIngredientFilterPresentsSelectionSheet() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["검색"].tap()

        let ingredientFilterButton = app.buttons["ingredient-filter-button"]
        XCTAssertTrue(ingredientFilterButton.waitForExistence(timeout: 5))

        ingredientFilterButton.tap()

        XCTAssertTrue(app.staticTexts["재료를 골라 검색 결과를 좁혀보세요."].waitForExistence(timeout: 5))
    }
}
