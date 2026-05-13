import XCTest
@testable import NuguSauce

final class CachingAPIClientTests: XCTestCase {
    func testRecipeListCacheNormalizesEquivalentQueries() async throws {
        let authStore = CachingTestAuthStore()
        let upstream = CountingAPIClient(authStore: authStore)
        let client = CachingAPIClient(upstream: upstream, authStore: authStore)

        let first = try await client.fetchRecipeSearchPage(
            query: RecipeListQuery(keyword: "  마라 ", tagIDs: [2, 1], ingredientIDs: [3], sort: .popular),
            cursor: nil,
            limit: 20
        )
        let second = try await client.fetchRecipeSearchPage(
            query: RecipeListQuery(keyword: "마라", tagIDs: [1, 2], ingredientIDs: [3], sort: .popular),
            cursor: nil,
            limit: 20
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(upstream.fetchRecipeSearchPageCallCount, 1)

        _ = try await client.fetchRecipeSearchPage(
            query: RecipeListQuery(keyword: "마라", tagIDs: [1, 2], ingredientIDs: [3], sort: .recent),
            cursor: nil,
            limit: 20
        )
        XCTAssertEqual(upstream.fetchRecipeSearchPageCallCount, 2)

        _ = try await client.fetchRecipeSearchPage(
            query: RecipeListQuery(keyword: "마라", tagIDs: [1, 2], ingredientIDs: [3], sort: .popular),
            cursor: nil,
            limit: 10
        )
        XCTAssertEqual(upstream.fetchRecipeSearchPageCallCount, 3)
    }

    @MainActor
    func testFavoritesRefreshBypassesTTL() async {
        let authStore = CachingTestAuthStore(memberID: 1)
        let upstream = CountingAPIClient(authStore: authStore)
        let client = CachingAPIClient(upstream: upstream, authStore: authStore)
        let viewModel = FavoritesViewModel(apiClient: client, authStore: authStore)

        await viewModel.load()
        await viewModel.load()
        XCTAssertEqual(upstream.fetchFavoriteRecipesCallCount, 1)

        await viewModel.refresh()
        XCTAssertEqual(upstream.fetchFavoriteRecipesCallCount, 2)
    }

    func testPrivateCacheIsIsolatedAcrossMembers() async throws {
        let authStore = CachingTestAuthStore(memberID: 1)
        let upstream = CountingAPIClient(authStore: authStore)
        let client = CachingAPIClient(upstream: upstream, authStore: authStore)

        let memberARecipes = try await client.fetchFavoriteRecipes()
        _ = try await client.fetchFavoriteRecipes()
        XCTAssertEqual(memberARecipes.map(\.id), [1])
        XCTAssertEqual(upstream.fetchFavoriteRecipesCallCount, 1)

        authStore.setMemberID(2)
        let memberBRecipes = try await client.fetchFavoriteRecipes()

        XCTAssertEqual(memberBRecipes.map(\.id), [2])
        XCTAssertEqual(upstream.fetchFavoriteRecipesCallCount, 2)
    }

    func testAnonymousAndAuthenticatedRecipeListCachesAreSeparate() async throws {
        let authStore = CachingTestAuthStore()
        let upstream = CountingAPIClient(authStore: authStore)
        let client = CachingAPIClient(upstream: upstream, authStore: authStore)
        let query = RecipeListQuery(sort: .popular)

        let anonymousPage = try await client.fetchRecipeSearchPage(query: query, cursor: nil, limit: 20)
        XCTAssertFalse(anonymousPage.items.first?.isFavorite == true)
        XCTAssertEqual(upstream.fetchRecipeSearchPageCallCount, 1)

        authStore.setMemberID(7)
        let memberPage = try await client.fetchRecipeSearchPage(query: query, cursor: nil, limit: 20)

        XCTAssertTrue(memberPage.items.first?.isFavorite == true)
        XCTAssertEqual(upstream.fetchRecipeSearchPageCallCount, 2)
    }

    func testMasterDataCacheSurvivesBucketChanges() async throws {
        let authStore = CachingTestAuthStore()
        let upstream = CountingAPIClient(authStore: authStore)
        let client = CachingAPIClient(upstream: upstream, authStore: authStore)

        _ = try await client.fetchIngredients()
        _ = try await client.fetchTags()

        authStore.setMemberID(1)
        _ = try await client.fetchIngredients()
        _ = try await client.fetchTags()

        authStore.setMemberID(2)
        _ = try await client.fetchIngredients()
        _ = try await client.fetchTags()

        XCTAssertEqual(upstream.fetchIngredientsCallCount, 1)
        XCTAssertEqual(upstream.fetchTagsCallCount, 1)
    }

    func testAuthenticatedWithoutMemberDoesNotReusePrivateCache() async throws {
        let authStore = CachingTestAuthStore(authenticatedWithoutMember: true)
        let upstream = CountingAPIClient(authStore: authStore)
        let client = CachingAPIClient(upstream: upstream, authStore: authStore)

        _ = try await client.fetchFavoriteRecipes()
        _ = try await client.fetchFavoriteRecipes()

        XCTAssertEqual(upstream.fetchFavoriteRecipesCallCount, 2)
    }

    func testMidflightBucketTransitionDoesNotWriteThroughToNewBucket() async throws {
        let authStore = CachingTestAuthStore(authenticatedWithoutMember: true)
        let upstream = CountingAPIClient(authStore: authStore)
        upstream.suspendNextFavoriteFetch = true
        let client = CachingAPIClient(upstream: upstream, authStore: authStore)

        let task = Task {
            try await client.fetchFavoriteRecipes()
        }
        await upstream.waitUntilFavoriteFetchStarts()

        authStore.setMemberID(7)
        upstream.completeFavoriteFetch(with: [Self.recipe(id: 99, isFavorite: true)])
        let inFlightRecipes = try await task.value
        XCTAssertEqual(inFlightRecipes.map(\.id), [99])

        let memberRecipes = try await client.fetchFavoriteRecipes()
        XCTAssertEqual(memberRecipes.map(\.id), [7])
        XCTAssertEqual(upstream.fetchFavoriteRecipesCallCount, 2)
    }

    func testDuplicateFavoriteInvalidatesAffectedReadsAndRethrows() async throws {
        let authStore = CachingTestAuthStore(memberID: 3)
        let upstream = CountingAPIClient(authStore: authStore)
        let client = CachingAPIClient(upstream: upstream, authStore: authStore)
        let query = RecipeListQuery(sort: .popular)

        _ = try await client.fetchRecipeSearchPage(query: query, cursor: nil, limit: 20)
        _ = try await client.fetchRecipeDetail(id: 10)
        _ = try await client.fetchFavoriteRecipes()
        upstream.favoriteAddError = ApiError(code: ApiErrorCode.duplicateFavorite, message: "duplicate", detail: nil)

        do {
            _ = try await client.addFavorite(recipeID: 10)
            XCTFail("Expected duplicate favorite error")
        } catch let error as ApiError {
            XCTAssertEqual(error.code, ApiErrorCode.duplicateFavorite)
        }

        _ = try await client.fetchRecipeSearchPage(query: query, cursor: nil, limit: 20)
        _ = try await client.fetchRecipeDetail(id: 10)
        _ = try await client.fetchFavoriteRecipes()

        XCTAssertEqual(upstream.fetchRecipeSearchPageCallCount, 2)
        XCTAssertEqual(upstream.fetchRecipeDetailCallCount, 2)
        XCTAssertEqual(upstream.fetchFavoriteRecipesCallCount, 2)
    }

    func testFavoriteNotFoundInvalidatesAffectedReadsAndRethrows() async throws {
        let authStore = CachingTestAuthStore(memberID: 3)
        let upstream = CountingAPIClient(authStore: authStore)
        let client = CachingAPIClient(upstream: upstream, authStore: authStore)
        let query = RecipeListQuery(sort: .popular)

        _ = try await client.fetchRecipeSearchPage(query: query, cursor: nil, limit: 20)
        _ = try await client.fetchRecipeDetail(id: 10)
        _ = try await client.fetchFavoriteRecipes()
        upstream.favoriteDeleteError = ApiError(code: ApiErrorCode.favoriteNotFound, message: "missing", detail: nil)

        do {
            try await client.deleteFavorite(recipeID: 10)
            XCTFail("Expected favorite not found error")
        } catch let error as ApiError {
            XCTAssertEqual(error.code, ApiErrorCode.favoriteNotFound)
        }

        _ = try await client.fetchRecipeSearchPage(query: query, cursor: nil, limit: 20)
        _ = try await client.fetchRecipeDetail(id: 10)
        _ = try await client.fetchFavoriteRecipes()

        XCTAssertEqual(upstream.fetchRecipeSearchPageCallCount, 2)
        XCTAssertEqual(upstream.fetchRecipeDetailCallCount, 2)
        XCTAssertEqual(upstream.fetchFavoriteRecipesCallCount, 2)
    }

    func testRecipeUpdateInvalidatesAffectedReads() async throws {
        let authStore = CachingTestAuthStore(memberID: 3)
        let upstream = CountingAPIClient(authStore: authStore)
        let client = CachingAPIClient(upstream: upstream, authStore: authStore)
        let query = RecipeListQuery(sort: .popular)

        _ = try await client.fetchRecipeSearchPage(query: query, cursor: nil, limit: 20)
        _ = try await client.fetchRecipeDetail(id: 10)
        _ = try await client.fetchFavoriteRecipes()
        _ = try await client.fetchMyRecipes()
        _ = try await client.fetchMyMember()

        _ = try await client.updateRecipe(
            id: 10,
            request: UpdateRecipeRequestDTO(
                title: "수정",
                description: "설명",
                imageId: nil,
                tips: nil,
                ingredients: [
                    CreateRecipeIngredientRequestDTO(ingredientId: 1, amount: 1.0, unit: "스푼", ratio: nil)
                ]
            )
        )

        _ = try await client.fetchRecipeSearchPage(query: query, cursor: nil, limit: 20)
        _ = try await client.fetchRecipeDetail(id: 10)
        _ = try await client.fetchFavoriteRecipes()
        _ = try await client.fetchMyRecipes()
        _ = try await client.fetchMyMember()

        XCTAssertEqual(upstream.fetchRecipeSearchPageCallCount, 2)
        XCTAssertEqual(upstream.fetchRecipeDetailCallCount, 2)
        XCTAssertEqual(upstream.fetchFavoriteRecipesCallCount, 2)
        XCTAssertEqual(upstream.fetchMyRecipesCallCount, 2)
        XCTAssertEqual(upstream.fetchMyMemberCallCount, 2)
    }

    func testRecipeDeleteInvalidatesAffectedReads() async throws {
        let authStore = CachingTestAuthStore(memberID: 3)
        let upstream = CountingAPIClient(authStore: authStore)
        let client = CachingAPIClient(upstream: upstream, authStore: authStore)
        let query = RecipeListQuery(sort: .popular)

        _ = try await client.fetchRecipeSearchPage(query: query, cursor: nil, limit: 20)
        _ = try await client.fetchRecipeDetail(id: 10)
        _ = try await client.fetchFavoriteRecipes()
        _ = try await client.fetchMyRecipes()
        _ = try await client.fetchMyMember()

        try await client.deleteRecipe(id: 10)

        _ = try await client.fetchRecipeSearchPage(query: query, cursor: nil, limit: 20)
        _ = try await client.fetchRecipeDetail(id: 10)
        _ = try await client.fetchFavoriteRecipes()
        _ = try await client.fetchMyRecipes()
        _ = try await client.fetchMyMember()

        XCTAssertEqual(upstream.fetchRecipeSearchPageCallCount, 2)
        XCTAssertEqual(upstream.fetchRecipeDetailCallCount, 2)
        XCTAssertEqual(upstream.fetchFavoriteRecipesCallCount, 2)
        XCTAssertEqual(upstream.fetchMyRecipesCallCount, 2)
        XCTAssertEqual(upstream.fetchMyMemberCallCount, 2)
    }

    fileprivate static func recipe(id: Int, isFavorite: Bool = false) -> RecipeSummaryDTO {
        RecipeSummaryDTO(
            id: id,
            title: "소스 \(id)",
            description: "테스트 소스",
            imageUrl: nil,
            visibility: .visible,
            ratingSummary: RatingSummaryDTO(averageRating: 4.5, reviewCount: 2),
            tags: [],
            favoriteCount: 1,
            isFavorite: isFavorite,
            createdAt: "2026-04-25T00:00:00Z"
        )
    }

    fileprivate static func detail(id: Int, isFavorite: Bool = false) -> RecipeDetailDTO {
        RecipeDetailDTO(
            id: id,
            title: "상세 \(id)",
            description: "테스트 상세",
            imageUrl: nil,
            tips: nil,
            authorId: nil,
            authorName: "NuguSauce",
            authorProfileImageUrl: nil,
            visibility: .visible,
            ingredients: [],
            tags: [],
            ratingSummary: RatingSummaryDTO(averageRating: 4.5, reviewCount: 2),
            favoriteCount: 1,
            isFavorite: isFavorite,
            createdAt: "2026-04-25T00:00:00Z",
            lastReviewedAt: nil
        )
    }
}

private final class CachingTestAuthStore: AuthSessionStoreProtocol {
    private(set) var currentSession: AuthSession?

    init(memberID: Int? = nil, authenticatedWithoutMember: Bool = false) {
        if let memberID {
            setMemberID(memberID)
        } else if authenticatedWithoutMember {
            currentSession = AuthSession(displayName: "전이 사용자", accessToken: "test-access", refreshToken: nil)
        }
    }

    var isAuthenticated: Bool {
        currentSession?.profileSetupRequired == false
    }

    var accessToken: String? {
        guard isAuthenticated else {
            return nil
        }
        return currentSession?.accessToken
    }

    func restore() {}

    @discardableResult
    func saveSession(accessToken: String, refreshToken: String?, displayName: String?) -> Bool {
        currentSession = AuthSession(displayName: displayName ?? "테스트 사용자", accessToken: accessToken, refreshToken: refreshToken)
        return true
    }

    func updateMemberProfile(_ member: MemberProfileDTO) {
        currentSession = AuthSession(
            displayName: member.displayName,
            accessToken: currentSession?.accessToken ?? "test-access",
            refreshToken: currentSession?.refreshToken,
            memberId: member.id,
            nickname: member.nickname,
            profileImageUrl: member.profileImageUrl,
            profileSetupRequired: member.profileSetupRequired ?? false
        )
    }

    func clear() {
        currentSession = nil
    }

    func setMemberID(_ memberID: Int) {
        updateMemberProfile(
            MemberProfileDTO(
                id: memberID,
                nickname: "tester\(memberID)",
                displayName: "테스터 \(memberID)",
                profileSetupRequired: false
            )
        )
    }
}

private final class CountingAPIClient: APIClientProtocol {
    private let authStore: CachingTestAuthStore
    private var favoriteFetchStarted = false
    private var favoriteFetchStartedContinuation: CheckedContinuation<Void, Never>?
    private var favoriteFetchCompletion: CheckedContinuation<[RecipeSummaryDTO], Never>?

    var suspendNextFavoriteFetch = false
    var favoriteAddError: Error?
    var favoriteDeleteError: Error?

    private(set) var fetchHomeCallCount = 0
    private(set) var fetchRecipeSearchPageCallCount = 0
    private(set) var fetchRecipeDetailCallCount = 0
    private(set) var fetchReviewsCallCount = 0
    private(set) var fetchIngredientsCallCount = 0
    private(set) var fetchTagsCallCount = 0
    private(set) var fetchFavoriteRecipesCallCount = 0
    private(set) var fetchMyRecipesCallCount = 0
    private(set) var fetchMyMemberCallCount = 0
    private(set) var updateRecipeCallCount = 0
    private(set) var deleteRecipeCallCount = 0
    private(set) var deleteMyAccountCallCount = 0

    init(authStore: CachingTestAuthStore) {
        self.authStore = authStore
    }

    func fetchHome() async throws -> HomeDTO {
        fetchHomeCallCount += 1
        let memberID = authStore.currentSession?.memberId
        let recipe = CachingAPIClientTests.recipe(
            id: memberID ?? RecipeSort.popular.rawValue.count,
            isFavorite: memberID != nil
        )
        return HomeDTO(popularTop: [recipe], recentTop: [recipe])
    }

    func fetchRecipeSearchPage(
        query: RecipeListQuery,
        cursor: String?,
        limit: Int
    ) async throws -> RecipeSearchPageDTO {
        fetchRecipeSearchPageCallCount += 1
        let memberID = authStore.currentSession?.memberId
        return RecipeSearchPageDTO(
            items: [
                CachingAPIClientTests.recipe(
                    id: memberID ?? query.sort.rawValue.count,
                    isFavorite: memberID != nil
                )
            ],
            nextCursor: nil,
            hasNext: false
        )
    }

    func fetchRecipeDetail(id: Int) async throws -> RecipeDetailDTO {
        fetchRecipeDetailCallCount += 1
        return CachingAPIClientTests.detail(id: id, isFavorite: authStore.currentSession?.memberId != nil)
    }

    func fetchReviews(recipeID: Int) async throws -> [RecipeReviewDTO] {
        fetchReviewsCallCount += 1
        return []
    }

    func fetchIngredients() async throws -> [IngredientDTO] {
        fetchIngredientsCallCount += 1
        return [IngredientDTO(id: 1, name: "마늘", category: "fresh_aromatic")]
    }

    func fetchTags() async throws -> [TagDTO] {
        fetchTagsCallCount += 1
        return [TagDTO(id: 1, name: "고소")]
    }

    func createImageUploadIntent(_ request: ImageUploadIntentRequestDTO) async throws -> ImageUploadIntentDTO {
        throw APIClientError.missingData
    }

    func uploadImage(
        data: Data,
        contentType: String,
        fileExtension: String,
        using intent: ImageUploadIntentDTO
    ) async throws {}

    func completeImageUpload(imageId: Int) async throws -> VerifiedImageDTO {
        throw APIClientError.missingData
    }

    func createRecipe(_ request: CreateRecipeRequestDTO) async throws -> RecipeDetailDTO {
        return CachingAPIClientTests.detail(id: 99)
    }

    func updateRecipe(id: Int, request: UpdateRecipeRequestDTO) async throws -> RecipeDetailDTO {
        updateRecipeCallCount += 1
        return CachingAPIClientTests.detail(id: id)
    }

    func deleteRecipe(id: Int) async throws {
        deleteRecipeCallCount += 1
    }

    func createReview(recipeID: Int, request: CreateReviewRequestDTO) async throws -> RecipeReviewDTO {
        RecipeReviewDTO(
            id: 1,
            recipeId: recipeID,
            authorId: authStore.currentSession?.memberId,
            authorName: "테스터",
            authorProfileImageUrl: nil,
            rating: request.rating,
            text: request.text,
            createdAt: "2026-04-25T00:00:00Z"
        )
    }

    func fetchMyRecipes() async throws -> [RecipeSummaryDTO] {
        fetchMyRecipesCallCount += 1
        return [CachingAPIClientTests.recipe(id: authStore.currentSession?.memberId ?? -1)]
    }

    func fetchFavoriteRecipes() async throws -> [RecipeSummaryDTO] {
        fetchFavoriteRecipesCallCount += 1

        if suspendNextFavoriteFetch {
            suspendNextFavoriteFetch = false
            favoriteFetchStarted = true
            favoriteFetchStartedContinuation?.resume()
            favoriteFetchStartedContinuation = nil
            return await withCheckedContinuation { continuation in
                favoriteFetchCompletion = continuation
            }
        }

        return [CachingAPIClientTests.recipe(id: authStore.currentSession?.memberId ?? -1, isFavorite: true)]
    }

    func waitUntilFavoriteFetchStarts() async {
        if favoriteFetchStarted {
            return
        }

        await withCheckedContinuation { continuation in
            favoriteFetchStartedContinuation = continuation
        }
    }

    func completeFavoriteFetch(with recipes: [RecipeSummaryDTO]) {
        favoriteFetchCompletion?.resume(returning: recipes)
        favoriteFetchCompletion = nil
    }

    func addFavorite(recipeID: Int) async throws -> FavoriteResponseDTO {
        if let favoriteAddError {
            throw favoriteAddError
        }
        return FavoriteResponseDTO(recipeId: recipeID, createdAt: "2026-04-25T00:00:00Z")
    }

    func deleteFavorite(recipeID: Int) async throws {
        if let favoriteDeleteError {
            throw favoriteDeleteError
        }
    }

    func fetchMyMember() async throws -> MemberProfileDTO {
        fetchMyMemberCallCount += 1
        let memberID = authStore.currentSession?.memberId ?? -1
        return MemberProfileDTO(
            id: memberID,
            nickname: "tester\(memberID)",
            displayName: "테스터 \(memberID)",
            profileSetupRequired: false
        )
    }

    func fetchMember(id: Int) async throws -> MemberProfileDTO {
        return MemberProfileDTO(id: id, nickname: "public\(id)", displayName: "공개 \(id)", profileSetupRequired: false)
    }

    func updateMyMember(nickname: String, profileImageId: Int?) async throws -> MemberProfileDTO {
        return MemberProfileDTO(
            id: authStore.currentSession?.memberId ?? -1,
            nickname: nickname,
            displayName: nickname,
            profileSetupRequired: false
        )
    }

    func updateMyMember(nickname: String, profileImageId: Int?, accessToken: String) async throws -> MemberProfileDTO {
        return MemberProfileDTO(
            id: authStore.currentSession?.memberId ?? -1,
            nickname: nickname,
            displayName: nickname,
            profileSetupRequired: false
        )
    }

    func deleteMyAccount() async throws {
        deleteMyAccountCallCount += 1
    }

    func authenticateWithKakao(idToken: String, nonce: String, kakaoAccessToken: String) async throws -> KakaoLoginResponseDTO {
        throw APIClientError.missingData
    }

    func authenticateWithApple(
        identityToken: String,
        nonce: String,
        authorizationCode: String?,
        userIdentifier: String?
    ) async throws -> SocialLoginResponseDTO {
        throw APIClientError.missingData
    }

    func reissue(refreshToken: String) async throws -> TokenResponseDTO {
        throw APIClientError.missingData
    }

    func fetchConsentStatus() async throws -> ConsentStatusDTO {
        ConsentStatusDTO(policies: [], missingPolicies: [], requiredConsentsAccepted: true)
    }

    func fetchConsentStatus(accessToken: String) async throws -> ConsentStatusDTO {
        ConsentStatusDTO(policies: [], missingPolicies: [], requiredConsentsAccepted: true)
    }

    func acceptConsents(_ request: ConsentAcceptRequestDTO) async throws -> ConsentStatusDTO {
        ConsentStatusDTO(policies: [], missingPolicies: [], requiredConsentsAccepted: true)
    }

    func acceptConsents(_ request: ConsentAcceptRequestDTO, accessToken: String) async throws -> ConsentStatusDTO {
        ConsentStatusDTO(policies: [], missingPolicies: [], requiredConsentsAccepted: true)
    }
}
