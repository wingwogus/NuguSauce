import XCTest
@testable import NuguSauce

@MainActor
final class ViewModelTests: XCTestCase {
    func testHomeLoadUsesClientResults() async {
        let viewModel = HomeViewModel(apiClient: TestAPIClient(recipes: [Self.recipe(id: 1, title: "건희 소스")]))

        await viewModel.load()

        XCTAssertEqual(viewModel.recipes.map(\.title), ["건희 소스"])
    }

    func testSearchQueryComposesFilters() {
        let viewModel = SearchViewModel(apiClient: TestAPIClient())
        viewModel.query = "건희"
        viewModel.selectedTagIDs = [1, 2]
        viewModel.selectedIngredientIDs = [2]
        viewModel.sort = .rating

        XCTAssertEqual(viewModel.queryModel.keyword, "건희")
        XCTAssertEqual(viewModel.queryModel.tagIDs, [1, 2])
        XCTAssertEqual(viewModel.queryModel.ingredientIDs, [2])
        XCTAssertEqual(viewModel.queryModel.sort, .rating)
    }

    func testSearchSelectedTagSummaryUsesLoadedFlavorTags() async {
        let viewModel = SearchViewModel(
            apiClient: TestAPIClient(
                tags: [
                    TagDTO(id: 1, name: "매콤"),
                    TagDTO(id: 2, name: "고소"),
                    TagDTO(id: 3, name: "달콤")
                ]
            )
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.selectedTagSummary, "전체 맛")

        viewModel.selectedTagIDs = [2]
        XCTAssertEqual(viewModel.selectedTagSummary, "고소")

        viewModel.selectedTagIDs = [1, 3]
        XCTAssertEqual(viewModel.selectedTagSummary, "매콤 외 1개")
    }

    func testSearchSelectedIngredientSummaryUsesLoadedIngredients() async {
        let viewModel = SearchViewModel(
            apiClient: TestAPIClient(
                ingredients: [
                    IngredientDTO(id: 1, name: "참기름", category: "oil"),
                    IngredientDTO(id: 2, name: "마늘", category: "aromatic"),
                    IngredientDTO(id: 3, name: "고수", category: "herb")
                ]
            )
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.selectedIngredientSummary, "전체 재료")

        viewModel.selectedIngredientIDs = [1]
        XCTAssertEqual(viewModel.selectedIngredientSummary, "참기름")

        viewModel.selectedIngredientIDs = [2, 3]
        XCTAssertEqual(viewModel.selectedIngredientSummary, "마늘 외 1개")
    }

    func testCreateRecipeValidationAndRequest() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let ingredient = IngredientDTO(id: 1, name: "참기름", category: "oil")
        let viewModel = CreateRecipeViewModel(apiClient: TestAPIClient(ingredients: [ingredient]), authStore: authStore)

        await viewModel.load()
        viewModel.addIngredient(ingredient)
        viewModel.title = "사천식 매콤 소스"
        viewModel.description = "매콤하고 고소한 조합"

        XCTAssertTrue(viewModel.canSubmit)
        XCTAssertNil(viewModel.makeRequest().imageUrl)
        XCTAssertFalse(viewModel.makeRequest().ingredients.isEmpty)
    }

    func testCreateRecipeQuickAddSectionsKeepEveryLoadedIngredient() async {
        let ingredients = (1...12).map { index in
            IngredientDTO(
                id: index,
                name: "재료 \(index)",
                category: index.isMultiple(of: 3) ? "sauce" : "spicy"
            )
        }
        let viewModel = CreateRecipeViewModel(
            apiClient: TestAPIClient(ingredients: ingredients),
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )

        await viewModel.load()

        let sectionIngredientIDs = viewModel.quickAddSections.flatMap(\.ingredients).map(\.id)
        XCTAssertEqual(sectionIngredientIDs.count, ingredients.count)
        XCTAssertEqual(Set(sectionIngredientIDs), Set(ingredients.map(\.id)))
        XCTAssertEqual(viewModel.quickAddSections.map(\.title), ["매운맛", "소스"])
    }

    func testCreateRecipeIngredientCategoryTitleUsesReadableKoreanLabels() {
        let viewModel = CreateRecipeViewModel(
            apiClient: TestAPIClient(),
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )

        XCTAssertEqual(viewModel.categoryTitle(for: IngredientDTO(id: 1, name: "다진 마늘", category: "aromatic")), "향신 채소")
        XCTAssertEqual(viewModel.categoryTitle(for: IngredientDTO(id: 2, name: "기타 재료", category: nil)), "기타")
    }

    func testFavoritesLoadUsesFavoriteEndpointWhenAuthenticated() async {
        let favoriteRecipe = Self.recipe(id: 2, title: "찜한 땅콩 소스")
        let client = TestAPIClient(
            recipes: [Self.recipe(id: 1, title: "홈 레시피")],
            favoriteRecipes: [favoriteRecipe]
        )
        let viewModel = FavoritesViewModel(
            apiClient: client,
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.recipes, [favoriteRecipe])
        XCTAssertEqual(client.fetchFavoriteRecipesCallCount, 1)
    }

    func testFavoritesLoadClearsDataWhenSessionEnds() async {
        let favoriteRecipe = Self.recipe(id: 2, title: "찜한 땅콩 소스")
        let client = TestAPIClient(favoriteRecipes: [favoriteRecipe])
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let viewModel = FavoritesViewModel(apiClient: client, authStore: authStore)

        await viewModel.load()
        XCTAssertEqual(viewModel.recipes, [favoriteRecipe])

        authStore.clear()
        await viewModel.load()

        XCTAssertTrue(viewModel.recipes.isEmpty)
    }

    func testAuthSessionRestoreAndClear() {
        let store = TestAuthSessionStore()

        XCTAssertFalse(store.isAuthenticated)
        store.saveSession(accessToken: "real-access-token", refreshToken: "real-refresh-token", displayName: "테스터")
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.currentSession?.displayName, "테스터")
        store.clear()
        XCTAssertFalse(store.isAuthenticated)
    }

    func testAuthSessionRestoreDoesNotClearCurrentSessionWhenTokenStoreIsUnavailable() {
        let store = AuthSessionStore(tokenStore: UnavailableAuthTokenStore())

        store.saveSession(accessToken: "live-access-token", refreshToken: nil, displayName: "테스터")
        store.restore()

        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.accessToken, "live-access-token")
        store.clear()
    }

    func testNonceGeneratorProducesURLSafeDistinctValues() throws {
        let first = try NonceGenerator.randomNonce()
        let second = try NonceGenerator.randomNonce()

        XCTAssertEqual(first.count, 32)
        XCTAssertEqual(second.count, 32)
        XCTAssertNotEqual(first, second)
        XCTAssertNil(first.range(of: #"[^0-9A-Za-z._-]"#, options: .regularExpression))
        XCTAssertNil(second.range(of: #"[^0-9A-Za-z._-]"#, options: .regularExpression))
    }

    func testKakaoBundleIDMismatchMessageNamesCurrentBundleID() {
        let error = NSError(
            domain: "KakaoSDK",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "KOE009 IOS bundleId validation failed."
            ]
        )

        let message = KakaoLoginErrorMessage.message(for: error, bundleIdentifier: "com.nugusauce.ios")

        XCTAssertEqual(message, "Kakao Developers의 iOS Bundle ID에 com.nugusauce.ios를 등록해주세요.")
    }

    func testKakaoInvalidTokenMessagePointsToBackendAudienceConfiguration() {
        let error = ApiError(code: ApiErrorCode.invalidKakaoToken, message: "invalid kakao token", detail: nil)

        let message = KakaoLoginErrorMessage.message(for: error)

        XCTAssertEqual(message, "카카오 토큰 검증에 실패했습니다. 백엔드 KAKAO_NATIVE_APP_KEY를 iOS Native App Key와 맞춰주세요. (AUTH_009)")
    }

    func testKakaoVerifiedEmailRequiredMessageExplainsConsent() {
        let error = ApiError(code: ApiErrorCode.kakaoVerifiedEmailRequired, message: "verified email required", detail: nil)

        let message = KakaoLoginErrorMessage.message(for: error)

        XCTAssertEqual(message, "카카오 계정의 인증된 이메일 제공 동의가 필요합니다. Kakao Developers 동의항목을 확인해주세요. (AUTH_012)")
    }

    func testKakaoLoginRequiresAdditionalConsentWhenEmailScopeIsMissing() {
        XCTAssertTrue(KakaoLoginRequiredScopes.needsAdditionalConsent(grantedScopes: ["openid"]))
        XCTAssertTrue(KakaoLoginRequiredScopes.needsAdditionalConsent(grantedScopes: ["account_email"]))
        XCTAssertTrue(KakaoLoginRequiredScopes.needsAdditionalConsent(grantedScopes: nil))
    }

    func testKakaoLoginDoesNotRequestAdditionalConsentWhenOIDCAndEmailScopesAreGranted() {
        XCTAssertFalse(KakaoLoginRequiredScopes.needsAdditionalConsent(grantedScopes: ["openid", "account_email"]))
    }

    private static func recipe(id: Int, title: String) -> RecipeSummaryDTO {
        RecipeSummaryDTO(
            id: id,
            title: title,
            description: "백엔드 응답",
            imageUrl: nil,
            authorType: .curated,
            visibility: .visible,
            ratingSummary: RatingSummaryDTO(averageRating: 4.7, reviewCount: 18),
            reviewTags: [],
            createdAt: "2026-04-25T00:00:00Z"
        )
    }
}

private final class TestAPIClient: APIClientProtocol {
    private let recipes: [RecipeSummaryDTO]
    private let favoriteRecipes: [RecipeSummaryDTO]
    private let ingredients: [IngredientDTO]
    private let tags: [TagDTO]
    private(set) var fetchFavoriteRecipesCallCount = 0

    init(
        recipes: [RecipeSummaryDTO] = [],
        favoriteRecipes: [RecipeSummaryDTO]? = nil,
        ingredients: [IngredientDTO] = [],
        tags: [TagDTO] = []
    ) {
        self.recipes = recipes
        self.favoriteRecipes = favoriteRecipes ?? recipes
        self.ingredients = ingredients
        self.tags = tags
    }

    func fetchRecipes(query: RecipeListQuery) async throws -> [RecipeSummaryDTO] {
        recipes
    }

    func fetchRecipeDetail(id: Int) async throws -> RecipeDetailDTO {
        RecipeDetailDTO(
            id: id,
            title: "상세",
            description: "백엔드 상세",
            imageUrl: nil,
            tips: nil,
            authorType: .curated,
            visibility: .visible,
            ingredients: [],
            reviewTags: [],
            ratingSummary: RatingSummaryDTO(averageRating: 0, reviewCount: 0),
            createdAt: "2026-04-25T00:00:00Z",
            lastReviewedAt: nil
        )
    }

    func fetchReviews(recipeID: Int) async throws -> [RecipeReviewDTO] { [] }
    func fetchIngredients() async throws -> [IngredientDTO] { ingredients }
    func fetchTags() async throws -> [TagDTO] { tags }
    func createRecipe(_ request: CreateRecipeRequestDTO) async throws -> RecipeDetailDTO {
        try await fetchRecipeDetail(id: 1)
    }
    func createReview(recipeID: Int, request: CreateReviewRequestDTO) async throws -> RecipeReviewDTO {
        RecipeReviewDTO(id: 1, recipeId: recipeID, rating: request.rating, text: request.text, tasteTags: [], createdAt: "2026-04-25T00:00:00Z")
    }
    func fetchMyRecipes() async throws -> [RecipeSummaryDTO] { recipes }
    func fetchFavoriteRecipes() async throws -> [RecipeSummaryDTO] {
        fetchFavoriteRecipesCallCount += 1
        return favoriteRecipes
    }
    func addFavorite(recipeID: Int) async throws -> FavoriteResponseDTO {
        FavoriteResponseDTO(recipeId: recipeID, createdAt: "2026-04-25T00:00:00Z")
    }
    func deleteFavorite(recipeID: Int) async throws {}
    func authenticateWithKakao(idToken: String, nonce: String, kakaoAccessToken: String) async throws -> TokenResponseDTO {
        TokenResponseDTO(accessToken: "real-access-token", refreshToken: "real-refresh-token")
    }
    func reissue(refreshToken: String) async throws -> TokenResponseDTO {
        TokenResponseDTO(accessToken: "reissued-access-token", refreshToken: refreshToken)
    }
}

private final class TestAuthSessionStore: AuthSessionStoreProtocol {
    private(set) var currentSession: AuthSession?

    init(accessToken: String? = nil) {
        if let accessToken {
            saveSession(accessToken: accessToken, refreshToken: nil, displayName: "테스터")
        }
    }

    var isAuthenticated: Bool {
        currentSession != nil
    }

    var accessToken: String? {
        currentSession?.accessToken
    }

    func restore() {}

    func saveSession(accessToken: String, refreshToken: String?, displayName: String?) {
        currentSession = AuthSession(
            displayName: displayName ?? "테스터",
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }

    func clear() {
        currentSession = nil
    }
}

private struct UnavailableAuthTokenStore: AuthTokenStore {
    func save(_ value: String, account: KeychainAccount) -> Bool {
        false
    }

    func read(account: KeychainAccount) -> String? {
        nil
    }

    func delete(account: KeychainAccount) -> Bool {
        true
    }
}
