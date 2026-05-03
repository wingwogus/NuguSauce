import XCTest

final class NuguSauceUITests: XCTestCase {
    func testLaunchShowsPrimaryTabs() {
        let app = XCUIApplication()
        app.launch()

        let tabLabels = app.tabBars.buttons.allElementsBoundByIndex.map(\.label)

        XCTAssertEqual(tabLabels, ["홈", "찜", "등록", "검색", "프로필"])
    }

    func testHomeShowsReferenceSections() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["home.brand"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.profileButton"].exists)
        XCTAssertTrue(existsAny(app, identifiers: ["home.hero", "home.hero.empty", "home.loading", "home.error"]))
        XCTAssertTrue(existsAny(app, identifiers: ["home.popularRanking", "home.popularRanking.empty", "home.loading", "home.error"]))
        XCTAssertTrue(existsAny(app, identifiers: ["home.latest", "home.latest.empty", "home.loading", "home.error"]))
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

    func testProfileTabRoutesSignedOutUserToLoginScreen() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["프로필"].tap()

        XCTAssertTrue(app.staticTexts["로그인하고 소스 조합을 저장해보세요"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["로그인이 필요한 기능입니다."].exists)
    }

    private func existsAny(_ app: XCUIApplication, identifiers: [String]) -> Bool {
        identifiers.contains { identifier in
            app.descendants(matching: .any)[identifier].waitForExistence(timeout: 5)
        }
    }
}
