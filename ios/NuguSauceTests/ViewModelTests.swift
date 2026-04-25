import XCTest
@testable import NuguSauce

@MainActor
final class ViewModelTests: XCTestCase {
    func testHomeLoadExcludesHiddenRecipes() async {
        let viewModel = HomeViewModel(apiClient: MockAPIClient())

        await viewModel.load()

        XCTAssertFalse(viewModel.recipes.contains { $0.visibility == .hidden })
        XCTAssertFalse(viewModel.recipes.contains { $0.title == "숨김 처리된 샘플" })
    }

    func testSearchQueryComposesFilters() {
        let viewModel = SearchViewModel(apiClient: MockAPIClient())
        viewModel.query = "건희"
        viewModel.selectedTagIDs = [1, 2]
        viewModel.selectedIngredientIDs = [2]
        viewModel.sort = .rating

        XCTAssertEqual(viewModel.queryModel.keyword, "건희")
        XCTAssertEqual(viewModel.queryModel.tagIDs, [1, 2])
        XCTAssertEqual(viewModel.queryModel.ingredientIDs, [2])
        XCTAssertEqual(viewModel.queryModel.sort, .rating)
    }

    func testCreateRecipeValidationAndRequest() async {
        let authStore = MockAuthSessionStore(isAuthenticated: true)
        let viewModel = CreateRecipeViewModel(apiClient: MockAPIClient(), authStore: authStore)

        await viewModel.load()
        viewModel.title = "사천식 매콤 소스"
        viewModel.description = "매콤하고 고소한 조합"

        XCTAssertTrue(viewModel.canSubmit)
        XCTAssertNil(viewModel.makeRequest().imageUrl)
        XCTAssertFalse(viewModel.makeRequest().ingredients.isEmpty)
    }

    func testAuthSessionRestoreAndClear() {
        let store = MockAuthSessionStore(isAuthenticated: false)

        XCTAssertFalse(store.isAuthenticated)
        store.restore()
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.currentSession?.accessTokenRedacted, "mock-token-redacted")
        store.clear()
        XCTAssertFalse(store.isAuthenticated)
    }
}
