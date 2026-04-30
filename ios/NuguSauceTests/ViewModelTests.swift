import SwiftUI
import XCTest
@testable import NuguSauce

@MainActor
final class ViewModelTests: XCTestCase {
    func testThemePreferenceMapsToGlobalColorScheme() {
        XCTAssertNil(SauceThemePreference.system.colorScheme)
        XCTAssertEqual(SauceThemePreference.light.colorScheme, .light)
        XCTAssertEqual(SauceThemePreference.dark.colorScheme, .dark)
    }

    func testThemePreferenceFallsBackToSystemForUnknownStoredValue() {
        let restoredPreference = SauceThemePreference(rawValue: "legacy-or-corrupt-value") ?? .system

        XCTAssertEqual(restoredPreference, .system)
    }

    func testRootTabSelectionReturnsHomeAfterProfileSetupCompletes() {
        let tabSelection = RootTabSelection(selectedTab: .profile)

        tabSelection.profileSetupRequirementDidChange(isRequired: true)
        tabSelection.profileSetupRequirementDidChange(isRequired: false)

        XCTAssertEqual(tabSelection.selectedTab, .home)
    }

    func testRootTabSelectionDoesNotChangeTabsWithoutProfileSetupGate() {
        let tabSelection = RootTabSelection(selectedTab: .profile)

        tabSelection.profileSetupRequirementDidChange(isRequired: false)

        XCTAssertEqual(tabSelection.selectedTab, .profile)
    }

    func testRootTabSelectionRequestsLoginForProtectedTabsWhenSignedOut() {
        let tabSelection = RootTabSelection()

        tabSelection.select(.favorites, isAuthenticated: false)

        XCTAssertEqual(tabSelection.selectedTab, .favorites)
        XCTAssertEqual(tabSelection.loginRequiredTab, .favorites)
    }

    func testRootTabSelectionDoesNotRequestLoginForPublicTabsWhenSignedOut() {
        let tabSelection = RootTabSelection()

        tabSelection.select(.search, isAuthenticated: false)

        XCTAssertEqual(tabSelection.selectedTab, .search)
        XCTAssertNil(tabSelection.loginRequiredTab)
    }

    func testRootTabSelectionClearsLoginRequirementAfterAuthentication() {
        let tabSelection = RootTabSelection()
        tabSelection.select(.profile, isAuthenticated: false)

        tabSelection.authenticationDidChange(isAuthenticated: true)

        XCTAssertNil(tabSelection.loginRequiredTab)
    }

    func testHomeLoadUsesClientResults() async {
        let viewModel = HomeViewModel(apiClient: TestAPIClient(recipes: [Self.recipe(id: 1, title: "건희 소스")]))

        await viewModel.load()

        XCTAssertEqual(viewModel.recipes.map(\.title), ["건희 소스"])
    }

    func testHomeLoadSeparatesPopularAndRecentRails() async {
        let popularRecipes = (1...6).map { Self.recipe(id: $0, title: "인기 \($0)") }
        let recentRecipes = (10...15).map { Self.recipe(id: $0, title: "최신 \($0)") }
        let client = TestAPIClient(recipes: popularRecipes, recentRecipes: recentRecipes)
        let viewModel = HomeViewModel(apiClient: client)

        await viewModel.load()

        XCTAssertEqual(viewModel.weeklyPopularRecipes.map(\.title), ["인기 1", "인기 2", "인기 3", "인기 4", "인기 5"])
        XCTAssertEqual(viewModel.latestRecipeCards.map(\.title), ["최신 10", "최신 11", "최신 12", "최신 13", "최신 14"])
        XCTAssertEqual(client.fetchRecipeSorts.count, 2)
        XCTAssertTrue(client.fetchRecipeSorts.contains(.popular))
        XCTAssertTrue(client.fetchRecipeSorts.contains(.recent))
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
                    IngredientDTO(id: 2, name: "마늘", category: "fresh_aromatic"),
                    IngredientDTO(id: 3, name: "고수", category: "fresh_aromatic")
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
        XCTAssertNil(viewModel.makeRequest().imageId)
        XCTAssertNil(viewModel.makeRequest().tips)
        XCTAssertFalse(viewModel.makeRequest().ingredients.isEmpty)
    }

    func testCreateRecipeSubmitReturnsCreatedRecipeID() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let ingredient = IngredientDTO(id: 1, name: "참기름", category: "oil")
        let viewModel = CreateRecipeViewModel(apiClient: TestAPIClient(ingredients: [ingredient]), authStore: authStore)

        await viewModel.load()
        viewModel.addIngredient(ingredient)
        viewModel.title = "사천식 매콤 소스"

        let recipeID = await viewModel.submit()

        XCTAssertEqual(recipeID, 1)
        XCTAssertEqual(viewModel.submittedRecipeID, 1)
        XCTAssertTrue(viewModel.didSubmit)
    }

    func testCreateRecipeSubmitUploadsSelectedPhotoBeforeCreate() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let ingredient = IngredientDTO(id: 1, name: "참기름", category: "oil")
        let client = TestAPIClient(ingredients: [ingredient])
        let viewModel = CreateRecipeViewModel(apiClient: client, authStore: authStore)

        await viewModel.load()
        viewModel.addIngredient(ingredient)
        viewModel.title = "사진 소스"
        viewModel.setSelectedPhoto(data: Data([1, 2, 3]), contentType: "image/jpeg", fileExtension: "jpg")

        let recipeID = await viewModel.submit()

        XCTAssertEqual(recipeID, 1)
        XCTAssertEqual(client.uploadEvents, ["intent", "upload", "complete", "create"])
        XCTAssertEqual(client.imageUploadIntentRequests.first?.byteSize, 3)
        XCTAssertEqual(client.uploadedImageByteCounts, [3])
        XCTAssertEqual(client.completedImageIDs, [50])
        XCTAssertEqual(client.createdRecipeRequests.first?.imageId, 50)
    }

    func testCreateRecipeRatioIsTruncatedToTenthsInStateAndRequest() throws {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let ingredient = IngredientDTO(id: 1, name: "참기름", category: "oil")
        let viewModel = CreateRecipeViewModel(apiClient: TestAPIClient(), authStore: authStore)

        viewModel.addIngredient(ingredient)
        let editableIngredient = try XCTUnwrap(viewModel.ingredients.first)
        viewModel.updateRatio(for: editableIngredient, ratio: 0.39)
        let requestIngredient = try XCTUnwrap(viewModel.makeRequest().ingredients.first)

        XCTAssertEqual(viewModel.ingredients.first?.ratio ?? -1, 0.3, accuracy: 0.0001)
        XCTAssertEqual(requestIngredient.amount ?? -1, 0.3, accuracy: 0.0001)
        XCTAssertEqual(requestIngredient.ratio ?? -1, 0.3, accuracy: 0.0001)
    }

    func testRecipeMeasurementFormatterDisplaysTruncatedTenths() {
        XCTAssertEqual(RecipeMeasurementFormatter.oneDecimalText(0.39), "0.3")
        XCTAssertEqual(RecipeMeasurementFormatter.oneDecimalText(1.0), "1.0")
    }

    func testCreateRecipeQuickAddSectionsKeepEveryLoadedIngredient() async {
        let ingredients = (1...12).map { index in
            IngredientDTO(
                id: index,
                name: "재료 \(index)",
                category: index.isMultiple(of: 3) ? "sauce_paste" : "fresh_aromatic"
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
        XCTAssertEqual(viewModel.quickAddSections.map(\.title), ["소스/장류", "채소/향신 재료"])
    }

    func testCreateRecipeQuickAddSectionsUsePhysicalCategoryOrderAndIngredientNameSort() async {
        let chiliOil = IngredientDTO(id: 1, name: "고추기름", category: "oil")
        let vinegar = IngredientDTO(id: 2, name: "식초", category: "vinegar_citrus")
        let thaiChili = IngredientDTO(id: 3, name: "태국 고추", category: "fresh_aromatic")
        let peanutSauce = IngredientDTO(id: 4, name: "땅콩소스", category: "sauce_paste")
        let garlic = IngredientDTO(id: 5, name: "다진 마늘", category: "fresh_aromatic")
        let viewModel = CreateRecipeViewModel(
            apiClient: TestAPIClient(ingredients: [thaiChili, peanutSauce, vinegar, garlic, chiliOil]),
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.quickAddSections.map(\.title), ["소스/장류", "오일류", "식초/과즙", "채소/향신 재료"])
        XCTAssertEqual(viewModel.quickAddSections.last?.ingredients.map(\.name), ["다진 마늘", "태국 고추"])
    }

    func testCreateRecipeQuickAddSearchFiltersByIngredientNameAndCategoryTitle() async {
        let ingredients = [
            IngredientDTO(id: 1, name: "고추기름", category: "oil"),
            IngredientDTO(id: 2, name: "태국 고추", category: "fresh_aromatic"),
            IngredientDTO(id: 3, name: "땅콩소스", category: "sauce_paste"),
            IngredientDTO(id: 4, name: "간장", category: "sauce_paste")
        ]
        let viewModel = CreateRecipeViewModel(
            apiClient: TestAPIClient(ingredients: ingredients),
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )

        await viewModel.load()

        viewModel.ingredientSearchText = "고추"
        XCTAssertEqual(viewModel.quickAddSections.map(\.title), ["오일류", "채소/향신 재료"])
        XCTAssertEqual(viewModel.quickAddSections.flatMap(\.ingredients).map(\.name), ["고추기름", "태국 고추"])
        XCTAssertEqual(viewModel.quickAddVisibleIngredientCount, 2)

        viewModel.ingredientSearchText = "소스"
        XCTAssertEqual(viewModel.quickAddSections.map(\.title), ["소스/장류"])
        XCTAssertEqual(viewModel.quickAddSections.first?.ingredients.map(\.name), ["간장", "땅콩소스"])
    }

    func testCreateRecipeQuickAddSearchCanBeCleared() async {
        let viewModel = CreateRecipeViewModel(
            apiClient: TestAPIClient(
                ingredients: [
                    IngredientDTO(id: 1, name: "참기름", category: "oil"),
                    IngredientDTO(id: 2, name: "땅콩소스", category: "sauce_paste")
                ]
            ),
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )

        await viewModel.load()

        viewModel.ingredientSearchText = "없는 재료"
        XCTAssertTrue(viewModel.quickAddSections.isEmpty)
        XCTAssertTrue(viewModel.hasIngredientSearchText)

        viewModel.clearIngredientSearch()
        XCTAssertFalse(viewModel.hasIngredientSearchText)
        XCTAssertEqual(viewModel.quickAddVisibleIngredientCount, 2)
    }

    func testCreateRecipeIngredientCategoryTitleUsesReadableKoreanLabels() {
        let viewModel = CreateRecipeViewModel(
            apiClient: TestAPIClient(),
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )

        XCTAssertEqual(viewModel.categoryTitle(for: IngredientDTO(id: 1, name: "땅콩소스", category: "sauce_paste")), "소스/장류")
        XCTAssertEqual(viewModel.categoryTitle(for: IngredientDTO(id: 2, name: "고춧가루", category: "dry_seasoning")), "가루/시즈닝")
        XCTAssertEqual(viewModel.categoryTitle(for: IngredientDTO(id: 3, name: "기타 재료", category: nil)), "기타")
    }

    func testIngredientArtworkUsesBundledAssetsForKnownNamesAndCategoryFallbacks() {
        XCTAssertEqual(IngredientArtwork.assetName(forName: " 간장 ", category: "sauce_paste"), "IngredientSoySauce")
        XCTAssertEqual(IngredientArtwork.assetName(forName: "다진   마늘", category: "fresh_aromatic"), "IngredientGarlic")
        XCTAssertEqual(IngredientArtwork.assetName(forName: "알 수 없는 오일", category: "oil"), "IngredientOil")
        XCTAssertEqual(IngredientArtwork.assetName(forName: "미분류 재료", category: nil), "IngredientOther")
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

    func testAuthSessionUpdatesMemberProfile() {
        let store = TestAuthSessionStore(accessToken: "real-access-token")

        store.updateMemberProfile(
            MemberProfileDTO(
                id: 1,
                nickname: "소스장인",
                displayName: "소스장인",
                profileSetupRequired: false
            )
        )

        XCTAssertEqual(store.currentSession?.memberId, 1)
        XCTAssertEqual(store.currentSession?.nickname, "소스장인")
        XCTAssertEqual(store.currentSession?.displayName, "소스장인")
        XCTAssertEqual(store.currentSession?.profileSetupRequired, false)
    }

    func testAuthSessionRestoreDoesNotClearCurrentSessionWhenTokenStoreIsUnavailable() {
        let store = AuthSessionStore(tokenStore: ReadUnavailableAuthTokenStore(), userDefaults: makeUserDefaults())

        XCTAssertTrue(store.saveSession(accessToken: "live-access-token", refreshToken: nil, displayName: "테스터"))
        store.restore()

        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.accessToken, "live-access-token")
        store.clear()
    }

    func testAuthSessionPersistsTokensForNextStoreInstance() {
        let tokenStore = MemoryAuthTokenStore()
        let userDefaults = makeUserDefaults()

        let firstStore = AuthSessionStore(tokenStore: tokenStore, userDefaults: userDefaults)
        XCTAssertTrue(firstStore.saveSession(accessToken: "live-access-token", refreshToken: "live-refresh-token", displayName: "테스터"))

        let restoredStore = AuthSessionStore(tokenStore: tokenStore, userDefaults: userDefaults)

        XCTAssertTrue(restoredStore.isAuthenticated)
        XCTAssertEqual(restoredStore.accessToken, "live-access-token")
        XCTAssertEqual(restoredStore.currentSession?.refreshToken, "live-refresh-token")
        XCTAssertEqual(restoredStore.currentSession?.displayName, "테스터")
        XCTAssertNil(restoredStore.persistenceFailure)
    }

    func testAuthSessionPersistsKakaoMemberProfileSetupRequirement() {
        let tokenStore = MemoryAuthTokenStore()
        let userDefaults = makeUserDefaults()
        let firstStore = AuthSessionStore(tokenStore: tokenStore, userDefaults: userDefaults)
        let member = MemberProfileDTO(
            id: 7,
            nickname: nil,
            displayName: "사용자 7",
            profileSetupRequired: true
        )

        XCTAssertTrue(
            firstStore.saveSession(
                accessToken: "live-access-token",
                refreshToken: "live-refresh-token",
                member: member
            )
        )

        XCTAssertTrue(firstStore.requiresProfileSetup)
        XCTAssertEqual(firstStore.currentSession?.memberId, 7)
        XCTAssertEqual(firstStore.currentSession?.displayName, "사용자 7")
        XCTAssertNil(firstStore.currentSession?.nickname)

        let restoredStore = AuthSessionStore(tokenStore: tokenStore, userDefaults: userDefaults)

        XCTAssertTrue(restoredStore.requiresProfileSetup)
        XCTAssertEqual(restoredStore.currentSession?.memberId, 7)
        XCTAssertEqual(restoredStore.currentSession?.displayName, "사용자 7")
        XCTAssertNil(restoredStore.currentSession?.nickname)
    }

    func testAuthSessionSaveFailsClosedWhenAccessTokenCannotBePersisted() {
        let tokenStore = MemoryAuthTokenStore(failingSaveAccounts: [.accessToken])
        let store = AuthSessionStore(tokenStore: tokenStore, userDefaults: makeUserDefaults())

        let didSave = store.saveSession(accessToken: "live-access-token", refreshToken: "live-refresh-token", displayName: "테스터")

        XCTAssertFalse(didSave)
        XCTAssertFalse(store.isAuthenticated)
        XCTAssertEqual(store.persistenceFailure, .accessTokenSaveFailed)
        XCTAssertNil(tokenStore.read(account: .accessToken))
        XCTAssertNil(tokenStore.read(account: .refreshToken))
    }

    func testAuthSessionSaveFailsClosedWhenRefreshTokenCannotBePersisted() {
        let tokenStore = MemoryAuthTokenStore(failingSaveAccounts: [.refreshToken])
        let store = AuthSessionStore(tokenStore: tokenStore, userDefaults: makeUserDefaults())

        let didSave = store.saveSession(accessToken: "live-access-token", refreshToken: "live-refresh-token", displayName: "테스터")

        XCTAssertFalse(didSave)
        XCTAssertFalse(store.isAuthenticated)
        XCTAssertEqual(store.persistenceFailure, .refreshTokenSaveFailed)
        XCTAssertNil(tokenStore.read(account: .accessToken))
        XCTAssertNil(tokenStore.read(account: .refreshToken))
    }

    func testKeychainTokenStoreSavesUpdatesReadsAndDeletesWithIsolatedService() {
        let store = KeychainTokenStore(service: "com.nugusauce.ios.auth.tests.\(UUID().uuidString)")

        XCTAssertTrue(store.save("first-access-token", account: .accessToken))
        XCTAssertEqual(store.read(account: .accessToken), "first-access-token")

        XCTAssertTrue(store.save("updated-access-token", account: .accessToken))
        XCTAssertEqual(store.read(account: .accessToken), "updated-access-token")

        XCTAssertTrue(store.delete(account: .accessToken))
        XCTAssertNil(store.read(account: .accessToken))
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

    func testRecipeDetailSubmitReviewAddsReturnedAuthorName() async {
        let viewModel = RecipeDetailViewModel(
            recipeID: 10,
            apiClient: TestAPIClient(),
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )
        viewModel.reviewText = "고소하고 좋아요"
        viewModel.selectedRating = 4

        let didSubmit = await viewModel.submitReview()

        XCTAssertTrue(didSubmit)
        XCTAssertEqual(viewModel.reviews.first?.authorName, "테스터")
        XCTAssertEqual(viewModel.reviews.first?.rating, 4)
        XCTAssertEqual(viewModel.reviewText, "")
    }

    func testRecipeDetailLoadFetchesTasteTagsForReviewCompose() async {
        let viewModel = RecipeDetailViewModel(
            recipeID: 10,
            apiClient: TestAPIClient(
                tags: [
                    TagDTO(id: 1, name: "매콤해요"),
                    TagDTO(id: 2, name: "고소해요")
                ]
            ),
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.availableTasteTags.map(\.name), ["매콤해요", "고소해요"])
    }

    func testRecipeDetailLoadAppliesFavoriteStateFromDetail() async {
        let viewModel = RecipeDetailViewModel(
            recipeID: 10,
            apiClient: TestAPIClient(detailIsFavorite: true),
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )

        await viewModel.load()

        XCTAssertTrue(viewModel.isFavorite)
    }

    func testRecipeDetailFavoriteDuplicateErrorKeepsHeartFilled() async {
        let client = TestAPIClient(
            favoriteAddError: ApiError(
                code: ApiErrorCode.duplicateFavorite,
                message: "duplicate favorite",
                detail: nil
            )
        )
        let viewModel = RecipeDetailViewModel(
            recipeID: 10,
            apiClient: client,
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )

        await viewModel.toggleFavorite()

        XCTAssertTrue(viewModel.isFavorite)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testRecipeDetailFavoriteHeartFillsWhileAddRequestIsInFlight() async {
        let client = TestAPIClient(suspendFavoriteAdd: true)
        let viewModel = RecipeDetailViewModel(
            recipeID: 10,
            apiClient: client,
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )

        let task = Task {
            await viewModel.toggleFavorite()
        }
        await client.waitUntilFavoriteAddStarts()

        XCTAssertTrue(viewModel.isFavorite)
        XCTAssertTrue(viewModel.isUpdatingFavorite)

        client.completeFavoriteAdd()
        await task.value

        XCTAssertFalse(viewModel.isUpdatingFavorite)
    }

    func testRecipeDetailSubmitReviewSendsSelectedTasteTagIDs() async {
        let client = TestAPIClient(
            tags: [
                TagDTO(id: 3, name: "달콤해요"),
                TagDTO(id: 1, name: "매콤해요")
            ]
        )
        let viewModel = RecipeDetailViewModel(
            recipeID: 10,
            apiClient: client,
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )
        await viewModel.load()
        viewModel.beginReviewDraft()
        viewModel.reviewText = "매콤하고 달콤해서 좋아요"
        viewModel.toggleTasteTag(TagDTO(id: 3, name: "달콤해요"))
        viewModel.toggleTasteTag(TagDTO(id: 1, name: "매콤해요"))

        let didSubmit = await viewModel.submitReview()

        XCTAssertTrue(didSubmit)
        XCTAssertEqual(client.createdReviewRequests.first?.tasteTagIds, [1, 3])
        XCTAssertTrue(viewModel.selectedTasteTagIDs.isEmpty)
    }

    func testRecipeDetailRejectsReviewWhenLoggedOut() async {
        let viewModel = RecipeDetailViewModel(
            recipeID: 10,
            apiClient: TestAPIClient(),
            authStore: TestAuthSessionStore()
        )
        viewModel.reviewText = "로그아웃 리뷰"

        let didSubmit = await viewModel.submitReview()

        XCTAssertFalse(didSubmit)
        XCTAssertEqual(viewModel.errorMessage, "로그인이 필요합니다.")
        XCTAssertTrue(viewModel.reviews.isEmpty)
    }

    func testProfileLoadFetchesMemberProfileAndUpdatesSession() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let client = TestAPIClient(
            memberProfile: MemberProfileDTO(
                id: 7,
                nickname: nil,
                displayName: "사용자 7",
                profileSetupRequired: true
            )
        )
        let viewModel = ProfileViewModel(apiClient: client, authStore: authStore)

        await viewModel.load()

        XCTAssertEqual(viewModel.member?.id, 7)
        XCTAssertTrue(viewModel.profileSetupRequired)
        XCTAssertEqual(authStore.currentSession?.memberId, 7)
        XCTAssertEqual(authStore.currentSession?.displayName, "사용자 7")
    }

    func testProfileNicknameSaveUpdatesMemberProfile() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let client = TestAPIClient()
        let viewModel = ProfileViewModel(apiClient: client, authStore: authStore)
        viewModel.nicknameDraft = "소스장인"

        let didSave = await viewModel.saveNickname()

        XCTAssertTrue(didSave)
        XCTAssertEqual(client.updatedNicknames, ["소스장인"])
        XCTAssertEqual(viewModel.member?.nickname, "소스장인")
        XCTAssertEqual(authStore.currentSession?.displayName, "소스장인")
        XCTAssertEqual(authStore.currentSession?.profileSetupRequired, false)
    }

    func testProfileUsesUpdatedSessionAfterProfileSetupGateSavesNickname() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let client = TestAPIClient(
            memberProfile: MemberProfileDTO(
                id: 7,
                nickname: nil,
                displayName: "사용자 7",
                profileSetupRequired: true
            )
        )
        let profileViewModel = ProfileViewModel(apiClient: client, authStore: authStore)
        await profileViewModel.load()

        let setupViewModel = ProfileViewModel(apiClient: client, authStore: authStore)
        setupViewModel.nicknameDraft = "소스장인"
        let didSave = await setupViewModel.saveNickname()

        XCTAssertTrue(didSave)
        XCTAssertEqual(profileViewModel.displayName, "소스장인")
        XCTAssertFalse(profileViewModel.profileSetupRequired)
    }

    func testPublicProfileLoadFetchesPublicMemberProfile() async {
        let client = TestAPIClient(
            memberProfile: MemberProfileDTO(
                id: 8,
                nickname: "마라초보",
                displayName: "마라초보",
                profileSetupRequired: false,
                recipes: [Self.recipe(id: 81, title: "마라초보 소스")],
                favoriteRecipes: [Self.recipe(id: 82, title: "찜한 소스")]
            )
        )
        let viewModel = PublicProfileViewModel(memberID: 8, apiClient: client)

        await viewModel.load()

        XCTAssertEqual(client.fetchedMemberIDs, [8])
        XCTAssertEqual(viewModel.member?.displayName, "마라초보")
        XCTAssertEqual(viewModel.nicknameText, "@마라초보")
        XCTAssertEqual(viewModel.authoredRecipeSectionTitle, "마라초보가 올린 레시피")
        XCTAssertEqual(viewModel.recipes.map(\.id), [81])
        XCTAssertEqual(viewModel.favoriteRecipes.map(\.id), [82])
        XCTAssertNil(viewModel.errorMessage)
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
            isFavorite: false,
            createdAt: "2026-04-25T00:00:00Z"
        )
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "NuguSauceTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }
}

private final class TestAPIClient: APIClientProtocol {
    private let recipes: [RecipeSummaryDTO]
    private let recentRecipes: [RecipeSummaryDTO]
    private let favoriteRecipes: [RecipeSummaryDTO]
    private let ingredients: [IngredientDTO]
    private let tags: [TagDTO]
    private let detailIsFavorite: Bool
    private let favoriteAddError: Error?
    private let favoriteDeleteError: Error?
    private let suspendFavoriteAdd: Bool
    private var didStartFavoriteAdd = false
    private var favoriteAddStartedContinuation: CheckedContinuation<Void, Never>?
    private var favoriteAddCompletion: CheckedContinuation<Void, Error>?
    private var memberProfile: MemberProfileDTO
    private(set) var fetchFavoriteRecipesCallCount = 0
    private(set) var fetchRecipeSorts: [RecipeSort] = []
    private(set) var imageUploadIntentRequests: [ImageUploadIntentRequestDTO] = []
    private(set) var uploadedImageByteCounts: [Int] = []
    private(set) var completedImageIDs: [Int] = []
    private(set) var createdRecipeRequests: [CreateRecipeRequestDTO] = []
    private(set) var uploadEvents: [String] = []
    private(set) var createdReviewRequests: [CreateReviewRequestDTO] = []
    private(set) var updatedNicknames: [String] = []
    private(set) var fetchedMemberIDs: [Int] = []

    init(
        recipes: [RecipeSummaryDTO] = [],
        recentRecipes: [RecipeSummaryDTO]? = nil,
        favoriteRecipes: [RecipeSummaryDTO]? = nil,
        ingredients: [IngredientDTO] = [],
        tags: [TagDTO] = [],
        detailIsFavorite: Bool = false,
        favoriteAddError: Error? = nil,
        favoriteDeleteError: Error? = nil,
        suspendFavoriteAdd: Bool = false,
        memberProfile: MemberProfileDTO = MemberProfileDTO(
            id: 1,
            nickname: "테스터",
            displayName: "테스터",
            profileSetupRequired: false
        )
    ) {
        self.recipes = recipes
        self.recentRecipes = recentRecipes ?? recipes
        self.favoriteRecipes = favoriteRecipes ?? recipes
        self.ingredients = ingredients
        self.tags = tags
        self.detailIsFavorite = detailIsFavorite
        self.favoriteAddError = favoriteAddError
        self.favoriteDeleteError = favoriteDeleteError
        self.suspendFavoriteAdd = suspendFavoriteAdd
        self.memberProfile = memberProfile
    }

    func fetchRecipes(query: RecipeListQuery) async throws -> [RecipeSummaryDTO] {
        fetchRecipeSorts.append(query.sort)
        return query.sort == .recent ? recentRecipes : recipes
    }

    func fetchRecipeDetail(id: Int) async throws -> RecipeDetailDTO {
        return RecipeDetailDTO(
            id: id,
            title: "상세",
            description: "백엔드 상세",
            imageUrl: nil,
            tips: nil,
            authorType: .curated,
            authorId: nil,
            authorName: "NuguSauce",
            visibility: .visible,
            ingredients: [],
            reviewTags: [],
            ratingSummary: RatingSummaryDTO(averageRating: 0, reviewCount: 0),
            isFavorite: detailIsFavorite,
            createdAt: "2026-04-25T00:00:00Z",
            lastReviewedAt: nil
        )
    }

    func fetchReviews(recipeID: Int) async throws -> [RecipeReviewDTO] { [] }
    func fetchIngredients() async throws -> [IngredientDTO] { ingredients }
    func fetchTags() async throws -> [TagDTO] { tags }
    func createImageUploadIntent(_ request: ImageUploadIntentRequestDTO) async throws -> ImageUploadIntentDTO {
        uploadEvents.append("intent")
        imageUploadIntentRequests.append(request)
        return ImageUploadIntentDTO(
            imageId: 50,
            upload: ImageUploadTargetDTO(
                url: "https://upload.example.test",
                method: "POST",
                headers: [:],
                fields: ["signature": "signed"],
                fileField: "file",
                expiresAt: "2026-04-28T14:30:00Z"
            ),
            constraints: ImageUploadConstraintsDTO(
                maxBytes: 5_242_880,
                allowedContentTypes: ["image/jpeg", "image/png", "image/heic", "image/heif"]
            )
        )
    }
    func uploadImage(
        data: Data,
        contentType: String,
        fileExtension: String,
        using intent: ImageUploadIntentDTO
    ) async throws {
        uploadEvents.append("upload")
        uploadedImageByteCounts.append(data.count)
    }
    func completeImageUpload(imageId: Int) async throws -> VerifiedImageDTO {
        uploadEvents.append("complete")
        completedImageIDs.append(imageId)
        return VerifiedImageDTO(
            imageId: imageId,
            imageUrl: "https://cdn.example.test/image",
            width: 800,
            height: 600
        )
    }
    func createRecipe(_ request: CreateRecipeRequestDTO) async throws -> RecipeDetailDTO {
        uploadEvents.append("create")
        createdRecipeRequests.append(request)
        return try await fetchRecipeDetail(id: 1)
    }
    func createReview(recipeID: Int, request: CreateReviewRequestDTO) async throws -> RecipeReviewDTO {
        createdReviewRequests.append(request)
        return RecipeReviewDTO(
            id: 1,
            recipeId: recipeID,
            authorId: 1,
            authorName: "테스터",
            rating: request.rating,
            text: request.text,
            tasteTags: [],
            createdAt: "2026-04-25T00:00:00Z"
        )
    }
    func fetchMyRecipes() async throws -> [RecipeSummaryDTO] { recipes }
    func fetchFavoriteRecipes() async throws -> [RecipeSummaryDTO] {
        fetchFavoriteRecipesCallCount += 1
        return favoriteRecipes
    }
    func waitUntilFavoriteAddStarts() async {
        if didStartFavoriteAdd {
            return
        }

        await withCheckedContinuation { continuation in
            favoriteAddStartedContinuation = continuation
        }
    }

    func completeFavoriteAdd() {
        favoriteAddCompletion?.resume(returning: ())
        favoriteAddCompletion = nil
    }

    func addFavorite(recipeID: Int) async throws -> FavoriteResponseDTO {
        if suspendFavoriteAdd {
            try await withCheckedThrowingContinuation { continuation in
                favoriteAddCompletion = continuation
                didStartFavoriteAdd = true
                favoriteAddStartedContinuation?.resume()
                favoriteAddStartedContinuation = nil
            }
        }
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
    func fetchMyMember() async throws -> MemberProfileDTO { memberProfile }
    func fetchMember(id: Int) async throws -> MemberProfileDTO {
        fetchedMemberIDs.append(id)
        return memberProfile
    }
    func updateMyMember(nickname: String) async throws -> MemberProfileDTO {
        updatedNicknames.append(nickname)
        memberProfile = MemberProfileDTO(
            id: memberProfile.id,
            nickname: nickname,
            displayName: nickname,
            profileSetupRequired: false
        )
        return memberProfile
    }
    func authenticateWithKakao(idToken: String, nonce: String, kakaoAccessToken: String) async throws -> KakaoLoginResponseDTO {
        KakaoLoginResponseDTO(accessToken: "real-access-token", refreshToken: "real-refresh-token", member: memberProfile)
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

    @discardableResult
    func saveSession(accessToken: String, refreshToken: String?, displayName: String?) -> Bool {
        currentSession = AuthSession(
            displayName: displayName ?? "테스터",
            accessToken: accessToken,
            refreshToken: refreshToken
        )
        return true
    }

    func updateMemberProfile(_ member: MemberProfileDTO) {
        guard let currentSession else {
            return
        }
        self.currentSession = AuthSession(
            displayName: member.displayName,
            accessToken: currentSession.accessToken,
            refreshToken: currentSession.refreshToken,
            memberId: member.id,
            nickname: member.nickname,
            profileSetupRequired: member.profileSetupRequired ?? false
        )
    }

    func clear() {
        currentSession = nil
    }
}

private final class MemoryAuthTokenStore: AuthTokenStore {
    private var values: [KeychainAccount: String]
    private let failingSaveAccounts: Set<KeychainAccount>

    init(values: [KeychainAccount: String] = [:], failingSaveAccounts: Set<KeychainAccount> = []) {
        self.values = values
        self.failingSaveAccounts = failingSaveAccounts
    }

    func save(_ value: String, account: KeychainAccount) -> Bool {
        guard !failingSaveAccounts.contains(account) else {
            return false
        }
        values[account] = value
        return true
    }

    func read(account: KeychainAccount) -> String? {
        values[account]
    }

    func delete(account: KeychainAccount) -> Bool {
        values.removeValue(forKey: account)
        return true
    }
}

private final class ReadUnavailableAuthTokenStore: AuthTokenStore {
    private var values: [KeychainAccount: String] = [:]

    func save(_ value: String, account: KeychainAccount) -> Bool {
        values[account] = value
        return true
    }

    func read(account: KeychainAccount) -> String? {
        nil
    }

    func delete(account: KeychainAccount) -> Bool {
        true
    }
}
