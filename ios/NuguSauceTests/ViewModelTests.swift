import SwiftUI
import UIKit
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

    func testLightSurfaceTokensRemainTonallySeparated() {
        let traits = UITraitCollection(userInterfaceStyle: .light)

        let surfaceContainer = Self.brightness(of: SauceColor.surfaceContainer, traits: traits)
        let surfaceContainerLow = Self.brightness(of: SauceColor.surfaceContainerLow, traits: traits)
        let surface = Self.brightness(of: SauceColor.surface, traits: traits)
        let surfaceLowest = Self.brightness(of: SauceColor.surfaceLowest, traits: traits)

        XCTAssertLessThan(surfaceContainer, surfaceContainerLow)
        XCTAssertLessThan(surfaceContainerLow, surface)
        XCTAssertLessThan(surface, surfaceLowest)
        XCTAssertGreaterThan(surfaceLowest - surfaceContainerLow, 0.04)
    }

    func testImageUploadPreprocessorCapsOutputPixelsForUpload() {
        let originalImage = Self.noisyImage(width: 900, height: 700)
        let originalData = originalImage.pngData()!

        let normalizedData = ImageUploadPreprocessor.normalizedJPEGData(
            from: originalData,
            maxDimension: 320,
            compressionQuality: 0.82
        )
        let normalizedImage = UIImage(data: normalizedData)

        XCTAssertNotNil(normalizedImage)
        XCTAssertLessThanOrEqual(max(normalizedImage?.cgImage?.width ?? 0, normalizedImage?.cgImage?.height ?? 0), 320)
        XCTAssertLessThanOrEqual(normalizedData.count, ImageUploadPreprocessor.defaultMaxBytes)
    }

    func testImageUploadPreprocessorFitsDataUnderByteLimit() {
        let originalImage = Self.noisyImage(width: 900, height: 900)
        let originalData = originalImage.pngData()!

        let normalizedData = ImageUploadPreprocessor.normalizedJPEGData(
            from: originalData,
            maxDimension: 900,
            compressionQuality: 0.95,
            maxBytes: 160_000
        )

        XCTAssertLessThanOrEqual(normalizedData.count, 160_000)
        XCTAssertNotNil(UIImage(data: normalizedData))
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

    func testHomeLoadSeparatesHotPopularAndRecentSections() async {
        let hotRecipes = [Self.recipe(id: 99, title: "핫한 소스")]
        let popularRecipes = (1...6).map { Self.recipe(id: $0, title: "인기 \($0)") }
        let recentRecipes = (10...15).map { Self.recipe(id: $0, title: "최신 \($0)") }
        let client = TestAPIClient(hotRecipes: hotRecipes, recipes: popularRecipes, recentRecipes: recentRecipes)
        let viewModel = HomeViewModel(apiClient: client)

        await viewModel.load()

        XCTAssertEqual(viewModel.hotHeroRecipe?.title, "핫한 소스")
        XCTAssertEqual(viewModel.popularRankingRecipes.map(\.title), ["인기 1", "인기 2", "인기 3", "인기 4", "인기 5"])
        XCTAssertEqual(viewModel.latestGridRecipes.map(\.title), ["최신 10", "최신 11", "최신 12", "최신 13"])
        XCTAssertEqual(client.fetchRecipeSorts.count, 3)
        XCTAssertTrue(client.fetchRecipeSorts.contains(.hot))
        XCTAssertTrue(client.fetchRecipeSorts.contains(.popular))
        XCTAssertTrue(client.fetchRecipeSorts.contains(.recent))
    }

    func testHomeHeroFallsBackToPopularWhenHotIsEmpty() async {
        let popularRecipes = (1...2).map { Self.recipe(id: $0, title: "인기 \($0)") }
        let viewModel = HomeViewModel(apiClient: TestAPIClient(hotRecipes: [], recipes: popularRecipes))

        await viewModel.load()

        XCTAssertEqual(viewModel.hotHeroRecipe?.title, "인기 1")
        XCTAssertEqual(viewModel.popularRankingRecipes.map(\.title), ["인기 1", "인기 2"])
    }

    func testHomePopularRankingUsesPopularTopFive() async {
        let hotRecipes = [Self.recipe(id: 1, title: "핫한 인기 1")]
        let popularRecipes = (1...7).map { Self.recipe(id: $0, title: "인기 \($0)") }
        let viewModel = HomeViewModel(apiClient: TestAPIClient(hotRecipes: hotRecipes, recipes: popularRecipes))

        await viewModel.load()

        XCTAssertEqual(viewModel.popularRankingRecipes.map(\.title), ["인기 1", "인기 2", "인기 3", "인기 4", "인기 5"])
    }

    func testHomeLatestGridUsesAvailableRecentRecipesWhenUnderFour() async {
        let recentRecipes = (10...11).map { Self.recipe(id: $0, title: "최신 \($0)") }
        let viewModel = HomeViewModel(apiClient: TestAPIClient(recentRecipes: recentRecipes))

        await viewModel.load()

        XCTAssertEqual(viewModel.latestGridRecipes.map(\.title), ["최신 10", "최신 11"])
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

    func testSearchFilterDraftMirrorsAndAppliesCommittedFilters() {
        let viewModel = SearchViewModel(apiClient: TestAPIClient())
        viewModel.selectedTagIDs = [1, 3]
        viewModel.selectedIngredientIDs = [2]

        let draft = viewModel.makeFilterDraft()

        XCTAssertEqual(draft.tagIDs, [1, 3])
        XCTAssertEqual(draft.ingredientIDs, [2])

        viewModel.applyFilterDraft(SearchFilterDraft(tagIDs: [4], ingredientIDs: [5, 6]))

        XCTAssertEqual(viewModel.selectedTagIDs, [4])
        XCTAssertEqual(viewModel.selectedIngredientIDs, [5, 6])
        XCTAssertEqual(viewModel.queryModel.tagIDs, [4])
        XCTAssertEqual(viewModel.queryModel.ingredientIDs, [5, 6])
    }

    func testSearchFilterDraftResetDoesNotMutateCommittedFilters() {
        let viewModel = SearchViewModel(apiClient: TestAPIClient())
        viewModel.selectedTagIDs = [1]
        viewModel.selectedIngredientIDs = [2]

        let resetDraft = viewModel.resetFilterDraft()

        XCTAssertEqual(resetDraft, SearchFilterDraft.empty)
        XCTAssertEqual(viewModel.selectedTagIDs, [1])
        XCTAssertEqual(viewModel.selectedIngredientIDs, [2])
    }

    func testSearchFilterDraftApplyDoesNotFetchUntilSearchRuns() async throws {
        let client = TestAPIClient()
        let viewModel = SearchViewModel(apiClient: client)

        viewModel.applyFilterDraft(SearchFilterDraft(tagIDs: [7], ingredientIDs: [9]))

        XCTAssertTrue(client.fetchedRecipeQueries.isEmpty)

        try await viewModel.search()

        XCTAssertEqual(client.fetchedRecipeQueries.count, 1)
        XCTAssertEqual(client.fetchedRecipeQueries.first?.tagIDs ?? [], [7])
        XCTAssertEqual(client.fetchedRecipeQueries.first?.ingredientIDs ?? [], [9])
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

    func testCreateRecipeSubmitDoesNotExposeServerErrorMessage() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let ingredient = IngredientDTO(id: 1, name: "참기름", category: "oil")
        let client = TestAPIClient(
            ingredients: [ingredient],
            createRecipeError: ApiError(
                code: ApiErrorCode.internalError,
                message: "java.lang.IllegalStateException: failed in com.nugusauce.api.recipe",
                detail: nil
            )
        )
        let viewModel = CreateRecipeViewModel(apiClient: client, authStore: authStore)

        await viewModel.load()
        viewModel.addIngredient(ingredient)
        viewModel.title = "사천식 매콤 소스"
        let recipeID = await viewModel.submit()

        XCTAssertNil(recipeID)
        XCTAssertEqual(viewModel.errorMessage, "소스를 등록하지 못했어요.")
        XCTAssertFalse(viewModel.errorMessage?.contains("java.lang") == true)
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
        viewModel.photoRightsAccepted = true

        let recipeID = await viewModel.submit()

        XCTAssertEqual(recipeID, 1)
        XCTAssertEqual(client.uploadEvents, ["intent", "upload", "complete", "create"])
        XCTAssertEqual(client.imageUploadIntentRequests.first?.byteSize, 3)
        XCTAssertEqual(client.uploadedImageByteCounts, [3])
        XCTAssertEqual(client.completedImageIDs, [50])
        XCTAssertEqual(client.createdRecipeRequests.first?.imageId, 50)
    }

    func testCreateRecipeSubmitRequiresPhotoRightsConfirmation() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let ingredient = IngredientDTO(id: 1, name: "참기름", category: "oil")
        let client = TestAPIClient(ingredients: [ingredient])
        let viewModel = CreateRecipeViewModel(apiClient: client, authStore: authStore)

        await viewModel.load()
        viewModel.addIngredient(ingredient)
        viewModel.title = "사진 소스"
        viewModel.setSelectedPhoto(data: Data([1, 2, 3]), contentType: "image/jpeg", fileExtension: "jpg")

        let recipeID = await viewModel.submit()

        XCTAssertNil(recipeID)
        XCTAssertEqual(viewModel.errorMessage, "직접 촬영했거나 사용할 권리가 있는 사진만 올릴 수 있어요.")
        XCTAssertTrue(client.uploadEvents.isEmpty)
    }

    func testCreateRecipeConsentRequiredLoadsConsentStatusAndAcceptsRecovery() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let ingredient = IngredientDTO(id: 1, name: "참기름", category: "oil")
        let client = TestAPIClient(
            ingredients: [ingredient],
            createRecipeError: ApiError(code: ApiErrorCode.consentRequired, message: "consent required", detail: nil),
            consentStatus: Self.missingConsentStatus()
        )
        let viewModel = CreateRecipeViewModel(apiClient: client, authStore: authStore)

        await viewModel.load()
        viewModel.addIngredient(ingredient)
        viewModel.title = "동의 필요한 소스"

        let recipeID = await viewModel.submit()

        XCTAssertNil(recipeID)
        XCTAssertEqual(client.fetchConsentStatusCallCount, 1)
        XCTAssertEqual(viewModel.pendingConsentStatus?.missingPolicies.first?.policyType, "terms_of_service")
        XCTAssertEqual(viewModel.errorMessage, "필수 약관과 개인정보/콘텐츠 정책 동의가 필요해요.")

        let didAccept = await viewModel.acceptRequiredConsents()

        XCTAssertTrue(didAccept)
        XCTAssertNil(viewModel.pendingConsentStatus)
        XCTAssertEqual(client.acceptedConsentRequests.first?.acceptedPolicies.first?.policyType, "terms_of_service")
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

    func testCreateRecipeRatioSliderInputKeepsTenthsDespiteFloatingPointDrift() throws {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let ingredient = IngredientDTO(id: 1, name: "참기름", category: "oil")
        let viewModel = CreateRecipeViewModel(apiClient: TestAPIClient(), authStore: authStore)

        viewModel.addIngredient(ingredient)
        let editableIngredient = try XCTUnwrap(viewModel.ingredients.first)
        viewModel.updateRatio(for: editableIngredient, ratio: 1.199999999999)

        XCTAssertEqual(viewModel.ingredients.first?.ratio ?? -1, 1.2, accuracy: 0.0001)
        XCTAssertEqual(viewModel.ingredients.first?.amount ?? -1, 1.2, accuracy: 0.0001)
    }

    func testCreateRecipeRatioTextInputUpdatesRatioAndClampsRange() throws {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let ingredient = IngredientDTO(id: 1, name: "참기름", category: "oil")
        let viewModel = CreateRecipeViewModel(apiClient: TestAPIClient(), authStore: authStore)

        viewModel.addIngredient(ingredient)
        let editableIngredient = try XCTUnwrap(viewModel.ingredients.first)

        XCTAssertTrue(viewModel.updateRatio(for: editableIngredient, inputText: "2.76"))
        XCTAssertEqual(viewModel.ingredients.first?.ratio ?? -1, 2.7, accuracy: 0.0001)

        XCTAssertTrue(viewModel.updateRatio(for: editableIngredient, inputText: "0.04"))
        XCTAssertEqual(viewModel.ingredients.first?.ratio ?? -1, 0.1, accuracy: 0.0001)

        XCTAssertTrue(viewModel.updateRatio(for: editableIngredient, inputText: "7,8"))
        XCTAssertEqual(viewModel.ingredients.first?.ratio ?? -1, 5.0, accuracy: 0.0001)

        XCTAssertFalse(viewModel.updateRatio(for: editableIngredient, inputText: "소스"))
        XCTAssertEqual(viewModel.ingredients.first?.ratio ?? -1, 5.0, accuracy: 0.0001)

        XCTAssertFalse(viewModel.updateRatio(for: editableIngredient, inputText: "nan"))
        XCTAssertEqual(viewModel.ingredients.first?.ratio ?? -1, 5.0, accuracy: 0.0001)
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
            recipes: [Self.recipe(id: 1, title: "홈 소스")],
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
                profileImageUrl: "https://cdn.example.test/profile/1.jpg",
                profileSetupRequired: false
            )
        )

        XCTAssertEqual(store.currentSession?.memberId, 1)
        XCTAssertEqual(store.currentSession?.nickname, "소스장인")
        XCTAssertEqual(store.currentSession?.displayName, "소스장인")
        XCTAssertEqual(store.currentSession?.profileImageUrl, "https://cdn.example.test/profile/1.jpg")
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

    func testAuthSessionRejectsKakaoMemberUntilProfileSetupCompletes() {
        let tokenStore = MemoryAuthTokenStore()
        let userDefaults = makeUserDefaults()
        let store = AuthSessionStore(tokenStore: tokenStore, userDefaults: userDefaults)
        let member = MemberProfileDTO(
            id: 7,
            nickname: nil,
            displayName: "사용자 7",
            profileSetupRequired: true
        )

        XCTAssertFalse(
            store.saveSession(
                accessToken: "live-access-token",
                refreshToken: "live-refresh-token",
                member: member
            )
        )

        XCTAssertFalse(store.isAuthenticated)
        XCTAssertFalse(store.requiresProfileSetup)
        XCTAssertNil(store.currentSession)
        XCTAssertNil(tokenStore.read(account: .accessToken))
        XCTAssertNil(tokenStore.read(account: .refreshToken))
        XCTAssertEqual(store.persistenceFailure, .profileSetupIncomplete)
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

    func testAuthSessionPersistenceFailureMessageDoesNotExposeTokenStorageDetails() {
        let failures: [AuthSessionPersistenceFailure] = [
            .emptyAccessToken,
            .profileSetupIncomplete,
            .accessTokenSaveFailed,
            .refreshTokenSaveFailed,
            .refreshTokenDeleteFailed
        ]

        for failure in failures {
            XCTAssertEqual(failure.message, "로그인 세션을 안전하게 저장하지 못했어요. 다시 시도해주세요.")
            XCTAssertFalse(failure.message.localizedCaseInsensitiveContains("token"))
            XCTAssertFalse(failure.message.localizedCaseInsensitiveContains("keychain"))
        }
    }

    @MainActor
    func testLoginViewModelPersistsSessionOnlyAfterConsentAndNickname() async {
        let tokenStore = MemoryAuthTokenStore()
        let authStore = AuthSessionStore(tokenStore: tokenStore, userDefaults: makeUserDefaults())
        let client = TestAPIClient(
            consentStatus: Self.missingConsentStatus(),
            kakaoLoginNextStep: .consentRequired,
            memberProfile: MemberProfileDTO(
                id: 7,
                nickname: nil,
                displayName: "사용자 7",
                profileSetupRequired: true
            )
        )
        let viewModel = LoginViewModel(
            apiClient: client,
            authStore: authStore,
            kakaoLoginService: TestKakaoLoginService()
        )

        let didCompleteAfterKakao = await viewModel.loginWithKakao()

        XCTAssertFalse(didCompleteAfterKakao)
        XCTAssertFalse(authStore.isAuthenticated)
        XCTAssertNil(tokenStore.read(account: .accessToken))
        XCTAssertEqual(client.fetchConsentStatusAccessTokens, ["real-access-token"])
        XCTAssertEqual(viewModel.pendingConsentStatus?.missingPolicies.first?.policyType, "terms_of_service")
        XCTAssertEqual(viewModel.flowStep, .consent)

        let didCompleteAfterConsent = await viewModel.acceptRequiredConsents()

        XCTAssertFalse(didCompleteAfterConsent)
        XCTAssertFalse(authStore.isAuthenticated)
        XCTAssertNil(tokenStore.read(account: .accessToken))
        XCTAssertEqual(client.acceptConsentAccessTokens, ["real-access-token"])
        XCTAssertEqual(viewModel.flowStep, .nickname)

        viewModel.nicknameDraft = "소스장인"
        let didCompleteAfterNickname = await viewModel.saveNicknameAndCompleteLogin()

        XCTAssertTrue(didCompleteAfterNickname)
        XCTAssertTrue(authStore.isAuthenticated)
        XCTAssertEqual(tokenStore.read(account: .accessToken), "real-access-token")
        XCTAssertEqual(authStore.currentSession?.nickname, "소스장인")
        XCTAssertEqual(client.updateMemberAccessTokens, ["real-access-token"])
    }

    @MainActor
    func testLoginViewModelDoesNotPersistSessionWhenNicknameSaveFails() async {
        let tokenStore = MemoryAuthTokenStore()
        let authStore = AuthSessionStore(tokenStore: tokenStore, userDefaults: makeUserDefaults())
        let client = TestAPIClient(
            updateMemberError: ApiError(code: ApiErrorCode.duplicateNickname, message: "duplicate", detail: nil),
            consentStatus: Self.missingConsentStatus(),
            kakaoLoginNextStep: .consentRequired,
            memberProfile: MemberProfileDTO(
                id: 7,
                nickname: nil,
                displayName: "사용자 7",
                profileSetupRequired: true
            )
        )
        let viewModel = LoginViewModel(
            apiClient: client,
            authStore: authStore,
            kakaoLoginService: TestKakaoLoginService()
        )

        let didCompleteAfterKakao = await viewModel.loginWithKakao()
        XCTAssertFalse(didCompleteAfterKakao)
        let didCompleteAfterConsent = await viewModel.acceptRequiredConsents()
        XCTAssertFalse(didCompleteAfterConsent)

        viewModel.nicknameDraft = "중복닉"
        let didComplete = await viewModel.saveNicknameAndCompleteLogin()

        XCTAssertFalse(didComplete)
        XCTAssertFalse(authStore.isAuthenticated)
        XCTAssertNil(tokenStore.read(account: .accessToken))
        XCTAssertEqual(viewModel.nicknameErrorMessage, "이미 사용 중인 닉네임입니다.")
    }

    @MainActor
    func testLoginViewModelCompletesExistingUserWithoutFetchingConsentStatus() async {
        let tokenStore = MemoryAuthTokenStore()
        let authStore = AuthSessionStore(tokenStore: tokenStore, userDefaults: makeUserDefaults())
        let client = TestAPIClient(
            consentStatus: Self.missingConsentStatus(),
            kakaoLoginNextStep: .done,
            memberProfile: MemberProfileDTO(
                id: 7,
                nickname: "소스장인",
                displayName: "소스장인",
                profileSetupRequired: false
            )
        )
        let viewModel = LoginViewModel(
            apiClient: client,
            authStore: authStore,
            kakaoLoginService: TestKakaoLoginService()
        )

        let didComplete = await viewModel.loginWithKakao()

        XCTAssertTrue(didComplete)
        XCTAssertTrue(authStore.isAuthenticated)
        XCTAssertEqual(tokenStore.read(account: .accessToken), "real-access-token")
        XCTAssertEqual(client.fetchConsentStatusAccessTokens, [])
        XCTAssertNil(viewModel.pendingConsentStatus)
    }

    @MainActor
    func testLoginViewModelShowsNicknameForProfileRequiredWithoutFetchingConsentStatus() async {
        let tokenStore = MemoryAuthTokenStore()
        let authStore = AuthSessionStore(tokenStore: tokenStore, userDefaults: makeUserDefaults())
        let client = TestAPIClient(
            consentStatus: Self.missingConsentStatus(),
            kakaoLoginNextStep: .profileRequired,
            memberProfile: MemberProfileDTO(
                id: 7,
                nickname: nil,
                displayName: "사용자 7",
                profileSetupRequired: false
            )
        )
        let viewModel = LoginViewModel(
            apiClient: client,
            authStore: authStore,
            kakaoLoginService: TestKakaoLoginService()
        )

        let didComplete = await viewModel.loginWithKakao()

        XCTAssertFalse(didComplete)
        XCTAssertFalse(authStore.isAuthenticated)
        XCTAssertNil(tokenStore.read(account: .accessToken))
        XCTAssertEqual(client.fetchConsentStatusAccessTokens, [])
        XCTAssertEqual(viewModel.flowStep, .nickname)
        XCTAssertEqual(viewModel.nicknameDraft, "")
        XCTAssertNil(viewModel.pendingConsentStatus)
    }

    @MainActor
    func testLoginViewModelUsesConsentSpecificMessageWhenConsentStatusEndpointIsMissing() async {
        let tokenStore = MemoryAuthTokenStore()
        let authStore = AuthSessionStore(tokenStore: tokenStore, userDefaults: makeUserDefaults())
        let client = TestAPIClient(
            fetchConsentStatusError: ApiError(code: ApiErrorCode.resourceNotFound, message: "not found", detail: nil),
            kakaoLoginNextStep: .consentRequired,
            memberProfile: MemberProfileDTO(
                id: 7,
                nickname: nil,
                displayName: "사용자 7",
                profileSetupRequired: true
            )
        )
        let viewModel = LoginViewModel(
            apiClient: client,
            authStore: authStore,
            kakaoLoginService: TestKakaoLoginService()
        )

        let didComplete = await viewModel.loginWithKakao()

        XCTAssertFalse(didComplete)
        XCTAssertEqual(viewModel.errorMessage, "필수 약관 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요.")
        XCTAssertFalse(viewModel.errorMessage?.contains("요청한 정보를 찾을 수") == true)
        XCTAssertNil(viewModel.pendingConsentStatus)
        XCTAssertEqual(viewModel.flowStep, .consent)
        XCTAssertFalse(authStore.isAuthenticated)
    }

    func testConsentPolicyCopyProvidesInAppDetailsForRequiredPolicies() {
        XCTAssertFalse(ConsentPolicyCopy.paragraphs(for: "terms_of_service").isEmpty)
        XCTAssertFalse(ConsentPolicyCopy.paragraphs(for: "privacy_policy").isEmpty)
        XCTAssertFalse(ConsentPolicyCopy.paragraphs(for: "content_policy").isEmpty)
        XCTAssertTrue(ConsentPolicyCopy.paragraphs(for: "privacy_policy").joined().contains("개인정보"))
        XCTAssertTrue(ConsentPolicyCopy.paragraphs(for: "content_policy").joined().contains("사진"))
        XCTAssertEqual(ConsentPolicyCopy.policies(from: Self.missingConsentStatus()).map(\.policyType), [
            "terms_of_service"
        ])
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

    func testKakaoBundleIDMismatchMessageHidesSDKDetails() {
        let error = NSError(
            domain: "KakaoSDK",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "KOE009 IOS bundleId validation failed."
            ]
        )

        let message = KakaoLoginErrorMessage.message(for: error, bundleIdentifier: "com.nugusauce.ios")

        XCTAssertEqual(message, "카카오 로그인 설정을 확인할 수 없어요. 잠시 후 다시 시도해주세요.")
        XCTAssertFalse(message.contains("KOE009"))
        XCTAssertFalse(message.contains("com.nugusauce.ios"))
    }

    func testKakaoInvalidTokenMessageDoesNotExposeBackendConfiguration() {
        let error = ApiError(code: ApiErrorCode.invalidKakaoToken, message: "invalid kakao token", detail: nil)

        let message = KakaoLoginErrorMessage.message(for: error)

        XCTAssertEqual(message, "카카오 로그인에 실패했어요. 다시 시도해주세요.")
        XCTAssertFalse(message.contains("KAKAO_NATIVE_APP_KEY"))
        XCTAssertFalse(message.contains(ApiErrorCode.invalidKakaoToken))
    }

    func testKakaoVerifiedEmailRequiredMessageIsUserFacing() {
        let error = ApiError(code: ApiErrorCode.kakaoVerifiedEmailRequired, message: "verified email required", detail: nil)

        let message = KakaoLoginErrorMessage.message(for: error)

        XCTAssertEqual(message, "카카오 계정의 인증된 이메일 제공 동의가 필요해요.")
        XCTAssertFalse(message.contains(ApiErrorCode.kakaoVerifiedEmailRequired))
        XCTAssertFalse(message.contains("Kakao Developers"))
    }

    func testKakaoConsentRequiredMessageDoesNotLookLikeKakaoSDKFailure() {
        let error = ApiError(code: ApiErrorCode.consentRequired, message: "required policy versions are not configured", detail: nil)

        let message = KakaoLoginErrorMessage.message(for: error)

        XCTAssertEqual(message, "로그인을 완료하기 위한 약관 정보를 확인하지 못했어요. 잠시 후 다시 시도해주세요.")
        XCTAssertFalse(message.contains(ApiErrorCode.consentRequired))
        XCTAssertFalse(message.contains("카카오 로그인에 실패"))
    }

    func testKakaoUnknownApiErrorDoesNotExposeServerMessageOrCode() {
        let error = ApiError(
            code: ApiErrorCode.internalError,
            message: "java.lang.IllegalStateException: failed in com.nugusauce.api.auth",
            detail: nil
        )

        let message = KakaoLoginErrorMessage.message(for: error)

        XCTAssertEqual(message, "카카오 로그인에 실패했어요. 다시 시도해주세요.")
        XCTAssertFalse(message.contains(ApiErrorCode.internalError))
        XCTAssertFalse(message.contains("java.lang"))
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

    func testRecipeDetailFavoriteUnknownApiErrorDoesNotExposeServerMessage() async {
        let client = TestAPIClient(
            favoriteAddError: ApiError(
                code: ApiErrorCode.internalError,
                message: "java.lang.IllegalStateException: favorite write failed",
                detail: nil
            )
        )
        let viewModel = RecipeDetailViewModel(
            recipeID: 10,
            apiClient: client,
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )

        await viewModel.toggleFavorite()

        XCTAssertFalse(viewModel.isFavorite)
        XCTAssertEqual(viewModel.errorMessage, "찜 상태를 변경하지 못했어요.")
        XCTAssertFalse(viewModel.errorMessage?.contains("java.lang") == true)
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

    func testRecipeDetailConsentRequiredLoadsConsentStatusAndAcceptsRecovery() async {
        let client = TestAPIClient(
            createReviewError: ApiError(code: ApiErrorCode.consentRequired, message: "consent required", detail: nil),
            consentStatus: Self.missingConsentStatus()
        )
        let viewModel = RecipeDetailViewModel(
            recipeID: 10,
            apiClient: client,
            authStore: TestAuthSessionStore(accessToken: "real-access-token")
        )
        viewModel.reviewText = "고소하고 좋아요"

        let didSubmit = await viewModel.submitReview()

        XCTAssertFalse(didSubmit)
        XCTAssertEqual(client.fetchConsentStatusCallCount, 1)
        XCTAssertEqual(viewModel.pendingConsentStatus?.missingPolicies.first?.policyType, "terms_of_service")

        let didAccept = await viewModel.acceptRequiredConsents()

        XCTAssertTrue(didAccept)
        XCTAssertNil(viewModel.pendingConsentStatus)
        XCTAssertEqual(client.acceptedConsentRequests.count, 1)
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
                profileImageUrl: "https://cdn.example.test/profile/7.jpg",
                profileSetupRequired: true
            )
        )
        let viewModel = ProfileViewModel(apiClient: client, authStore: authStore)

        await viewModel.load()

        XCTAssertEqual(viewModel.member?.id, 7)
        XCTAssertTrue(viewModel.profileSetupRequired)
        XCTAssertEqual(viewModel.profileImageUrl, "https://cdn.example.test/profile/7.jpg")
        XCTAssertEqual(authStore.currentSession?.memberId, 7)
        XCTAssertEqual(authStore.currentSession?.displayName, "사용자 7")
        XCTAssertEqual(authStore.currentSession?.profileImageUrl, "https://cdn.example.test/profile/7.jpg")
    }

    func testProfileNicknameSaveUpdatesMemberProfile() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let client = TestAPIClient()
        let viewModel = ProfileViewModel(apiClient: client, authStore: authStore)
        viewModel.nicknameDraft = "소스장인"

        let didSave = await viewModel.saveNickname()

        XCTAssertTrue(didSave)
        XCTAssertEqual(client.updatedNicknames, ["소스장인"])
        XCTAssertEqual(client.updatedProfileImageIDs, [nil])
        XCTAssertEqual(viewModel.member?.nickname, "소스장인")
        XCTAssertEqual(authStore.currentSession?.displayName, "소스장인")
        XCTAssertEqual(authStore.currentSession?.profileSetupRequired, false)
    }

    func testProfileNicknameUnknownApiErrorDoesNotExposeCodeOrServerMessage() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let client = TestAPIClient(
            updateMemberError: ApiError(
                code: ApiErrorCode.internalError,
                message: "SQLIntegrityConstraintViolationException",
                detail: nil
            )
        )
        let viewModel = ProfileViewModel(apiClient: client, authStore: authStore)
        viewModel.nicknameDraft = "소스장인"

        let didSave = await viewModel.saveNickname()

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.nicknameErrorMessage, "닉네임을 저장하지 못했어요.")
        XCTAssertFalse(viewModel.nicknameErrorMessage?.contains(ApiErrorCode.internalError) == true)
        XCTAssertFalse(viewModel.nicknameErrorMessage?.contains("SQLIntegrity") == true)
    }

    func testProfileEditSaveUploadsSelectedPhotoAndUpdatesProfile() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let client = TestAPIClient(
            memberProfile: MemberProfileDTO(
                id: 7,
                nickname: "소스장인",
                displayName: "소스장인",
                profileImageUrl: nil,
                profileSetupRequired: false
            )
        )
        let viewModel = ProfileEditViewModel(apiClient: client, authStore: authStore)

        await viewModel.load()
        viewModel.setSelectedPhoto(data: Data([1, 2, 3]), contentType: "image/jpeg", fileExtension: "jpg")
        viewModel.photoRightsAccepted = true
        viewModel.nicknameDraft = "새닉네임"
        let didSave = await viewModel.save()

        XCTAssertTrue(didSave)
        XCTAssertEqual(client.uploadEvents, ["intent", "upload", "complete"])
        XCTAssertEqual(client.uploadedImageByteCounts, [3])
        XCTAssertEqual(client.completedImageIDs, [50])
        XCTAssertEqual(client.updatedNicknames, ["새닉네임"])
        XCTAssertEqual(client.updatedProfileImageIDs, [50])
        XCTAssertEqual(viewModel.member?.profileImageUrl, "https://cdn.example.test/profile/50.jpg")
        XCTAssertEqual(authStore.currentSession?.displayName, "새닉네임")
        XCTAssertEqual(authStore.currentSession?.profileImageUrl, "https://cdn.example.test/profile/50.jpg")
    }

    func testProfileEditSaveRequiresPhotoRightsConfirmation() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let client = TestAPIClient()
        let viewModel = ProfileEditViewModel(apiClient: client, authStore: authStore)

        await viewModel.load()
        viewModel.setSelectedPhoto(data: Data([1, 2, 3]), contentType: "image/jpeg", fileExtension: "jpg")
        viewModel.nicknameDraft = "새닉네임"

        let didSave = await viewModel.save()

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.errorMessage, "직접 촬영했거나 사용할 권리가 있는 사진만 올릴 수 있어요.")
        XCTAssertTrue(client.uploadEvents.isEmpty)
    }

    func testProfileEditConsentRequiredLoadsConsentStatusAndAcceptsRecovery() async {
        let authStore = TestAuthSessionStore(accessToken: "real-access-token")
        let client = TestAPIClient(
            imageUploadIntentError: ApiError(code: ApiErrorCode.consentRequired, message: "consent required", detail: nil),
            consentStatus: Self.missingConsentStatus()
        )
        let viewModel = ProfileEditViewModel(apiClient: client, authStore: authStore)

        await viewModel.load()
        viewModel.setSelectedPhoto(data: Data([1, 2, 3]), contentType: "image/jpeg", fileExtension: "jpg")
        viewModel.photoRightsAccepted = true
        viewModel.nicknameDraft = "새닉네임"

        let didSave = await viewModel.save()

        XCTAssertFalse(didSave)
        XCTAssertEqual(client.fetchConsentStatusCallCount, 1)
        XCTAssertEqual(viewModel.pendingConsentStatus?.missingPolicies.first?.policyType, "terms_of_service")

        let didAccept = await viewModel.acceptRequiredConsents()

        XCTAssertTrue(didAccept)
        XCTAssertNil(viewModel.pendingConsentStatus)
        XCTAssertEqual(client.acceptedConsentRequests.count, 1)
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
        XCTAssertEqual(viewModel.authoredRecipeSectionTitle, "마라초보가 올린 소스")
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
            visibility: .visible,
            ratingSummary: RatingSummaryDTO(averageRating: 4.7, reviewCount: 18),
            reviewTags: [],
            favoriteCount: 6,
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

    private static func brightness(of color: Color, traits: UITraitCollection) -> CGFloat {
        let resolvedColor = UIColor(color).resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        resolvedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return (red + green + blue) / 3
    }

    private static func noisyImage(width: Int, height: Int) -> UIImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                bytes[offset] = UInt8((x * 31 + y * 17) % 256)
                bytes[offset + 1] = UInt8((x * 11 + y * 47) % 256)
                bytes[offset + 2] = UInt8((x * 71 + y * 23) % 256)
                bytes[offset + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let data = Data(bytes)
        let provider = CGDataProvider(data: data as CFData)!
        let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
        return UIImage(cgImage: cgImage)
    }

    private static func missingConsentStatus() -> ConsentStatusDTO {
        let policy = ConsentPolicyDTO(
            policyType: "terms_of_service",
            version: "2026-05-01",
            title: "서비스 이용약관",
            url: "nugusauce://legal/terms",
            required: true,
            accepted: false,
            activeFrom: "2026-05-01T00:00:00Z"
        )
        return ConsentStatusDTO(
            policies: [policy],
            missingPolicies: [policy],
            requiredConsentsAccepted: false
        )
    }
}

private final class TestAPIClient: APIClientProtocol {
    private let hotRecipes: [RecipeSummaryDTO]
    private let recipes: [RecipeSummaryDTO]
    private let recentRecipes: [RecipeSummaryDTO]
    private let favoriteRecipes: [RecipeSummaryDTO]
    private let ingredients: [IngredientDTO]
    private let tags: [TagDTO]
    private let detailIsFavorite: Bool
    private let createRecipeError: Error?
    private let createReviewError: Error?
    private let imageUploadIntentError: Error?
    private let favoriteAddError: Error?
    private let favoriteDeleteError: Error?
    private let suspendFavoriteAdd: Bool
    private let updateMemberError: Error?
    private let fetchConsentStatusError: Error?
    private let kakaoLoginNextStep: KakaoLoginNextStepDTO
    private var consentStatus: ConsentStatusDTO
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
    private(set) var updatedProfileImageIDs: [Int?] = []
    private(set) var fetchedMemberIDs: [Int] = []
    private(set) var fetchedRecipeQueries: [RecipeListQuery] = []
    private(set) var fetchConsentStatusCallCount = 0
    private(set) var acceptedConsentRequests: [ConsentAcceptRequestDTO] = []
    private(set) var fetchConsentStatusAccessTokens: [String] = []
    private(set) var acceptConsentAccessTokens: [String] = []
    private(set) var updateMemberAccessTokens: [String] = []

    init(
        hotRecipes: [RecipeSummaryDTO]? = nil,
        recipes: [RecipeSummaryDTO] = [],
        recentRecipes: [RecipeSummaryDTO]? = nil,
        favoriteRecipes: [RecipeSummaryDTO]? = nil,
        ingredients: [IngredientDTO] = [],
        tags: [TagDTO] = [],
        detailIsFavorite: Bool = false,
        createRecipeError: Error? = nil,
        createReviewError: Error? = nil,
        imageUploadIntentError: Error? = nil,
        favoriteAddError: Error? = nil,
        favoriteDeleteError: Error? = nil,
        suspendFavoriteAdd: Bool = false,
        updateMemberError: Error? = nil,
        fetchConsentStatusError: Error? = nil,
        consentStatus: ConsentStatusDTO = ConsentStatusDTO(policies: [], missingPolicies: [], requiredConsentsAccepted: true),
        kakaoLoginNextStep: KakaoLoginNextStepDTO = .done,
        memberProfile: MemberProfileDTO = MemberProfileDTO(
            id: 1,
            nickname: "테스터",
            displayName: "테스터",
            profileSetupRequired: false
        )
    ) {
        self.hotRecipes = hotRecipes ?? recipes
        self.recipes = recipes
        self.recentRecipes = recentRecipes ?? recipes
        self.favoriteRecipes = favoriteRecipes ?? recipes
        self.ingredients = ingredients
        self.tags = tags
        self.detailIsFavorite = detailIsFavorite
        self.createRecipeError = createRecipeError
        self.createReviewError = createReviewError
        self.imageUploadIntentError = imageUploadIntentError
        self.favoriteAddError = favoriteAddError
        self.favoriteDeleteError = favoriteDeleteError
        self.suspendFavoriteAdd = suspendFavoriteAdd
        self.updateMemberError = updateMemberError
        self.fetchConsentStatusError = fetchConsentStatusError
        self.kakaoLoginNextStep = kakaoLoginNextStep
        self.consentStatus = consentStatus
        self.memberProfile = memberProfile
    }

    func fetchRecipes(query: RecipeListQuery) async throws -> [RecipeSummaryDTO] {
        fetchedRecipeQueries.append(query)
        fetchRecipeSorts.append(query.sort)
        switch query.sort {
        case .hot:
            return hotRecipes
        case .recent:
            return recentRecipes
        case .popular, .rating:
            return recipes
        }
    }

    func fetchRecipeDetail(id: Int) async throws -> RecipeDetailDTO {
        return RecipeDetailDTO(
            id: id,
            title: "상세",
            description: "백엔드 상세",
            imageUrl: nil,
            tips: nil,
            authorId: nil,
            authorName: "NuguSauce",
            authorProfileImageUrl: nil,
            visibility: .visible,
            ingredients: [],
            reviewTags: [],
            ratingSummary: RatingSummaryDTO(averageRating: 0, reviewCount: 0),
            favoriteCount: 0,
            isFavorite: detailIsFavorite,
            createdAt: "2026-04-25T00:00:00Z",
            lastReviewedAt: nil
        )
    }

    func fetchReviews(recipeID: Int) async throws -> [RecipeReviewDTO] { [] }
    func fetchIngredients() async throws -> [IngredientDTO] { ingredients }
    func fetchTags() async throws -> [TagDTO] { tags }
    func createImageUploadIntent(_ request: ImageUploadIntentRequestDTO) async throws -> ImageUploadIntentDTO {
        if let imageUploadIntentError {
            throw imageUploadIntentError
        }
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
        if let createRecipeError {
            throw createRecipeError
        }
        uploadEvents.append("create")
        createdRecipeRequests.append(request)
        return try await fetchRecipeDetail(id: 1)
    }
    func createReview(recipeID: Int, request: CreateReviewRequestDTO) async throws -> RecipeReviewDTO {
        if let createReviewError {
            throw createReviewError
        }
        createdReviewRequests.append(request)
        return RecipeReviewDTO(
            id: 1,
            recipeId: recipeID,
            authorId: 1,
            authorName: "테스터",
            authorProfileImageUrl: memberProfile.profileImageUrl,
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
    func updateMyMember(nickname: String, profileImageId: Int?) async throws -> MemberProfileDTO {
        if let updateMemberError {
            throw updateMemberError
        }
        updatedNicknames.append(nickname)
        updatedProfileImageIDs.append(profileImageId)
        let profileImageUrl = profileImageId.map { "https://cdn.example.test/profile/\($0).jpg" } ?? memberProfile.profileImageUrl
        memberProfile = MemberProfileDTO(
            id: memberProfile.id,
            nickname: nickname,
            displayName: nickname,
            profileImageUrl: profileImageUrl,
            profileSetupRequired: false
        )
        return memberProfile
    }
    func updateMyMember(nickname: String, profileImageId: Int?, accessToken: String) async throws -> MemberProfileDTO {
        updateMemberAccessTokens.append(accessToken)
        return try await updateMyMember(nickname: nickname, profileImageId: profileImageId)
    }
    func authenticateWithKakao(idToken: String, nonce: String, kakaoAccessToken: String) async throws -> KakaoLoginResponseDTO {
        KakaoLoginResponseDTO(
            accessToken: "real-access-token",
            refreshToken: "real-refresh-token",
            member: memberProfile,
            nextStep: kakaoLoginNextStep
        )
    }
    func reissue(refreshToken: String) async throws -> TokenResponseDTO {
        TokenResponseDTO(accessToken: "reissued-access-token", refreshToken: refreshToken)
    }
    func fetchConsentStatus() async throws -> ConsentStatusDTO {
        if let fetchConsentStatusError {
            throw fetchConsentStatusError
        }
        fetchConsentStatusCallCount += 1
        return consentStatus
    }
    func fetchConsentStatus(accessToken: String) async throws -> ConsentStatusDTO {
        fetchConsentStatusAccessTokens.append(accessToken)
        return try await fetchConsentStatus()
    }
    func acceptConsents(_ request: ConsentAcceptRequestDTO) async throws -> ConsentStatusDTO {
        acceptedConsentRequests.append(request)
        consentStatus = ConsentStatusDTO(
            policies: consentStatus.policies.map {
                ConsentPolicyDTO(
                    policyType: $0.policyType,
                    version: $0.version,
                    title: $0.title,
                    url: $0.url,
                    required: $0.required,
                    accepted: true,
                    activeFrom: $0.activeFrom
                )
            },
            missingPolicies: [],
            requiredConsentsAccepted: true
        )
        return consentStatus
    }
    func acceptConsents(_ request: ConsentAcceptRequestDTO, accessToken: String) async throws -> ConsentStatusDTO {
        acceptConsentAccessTokens.append(accessToken)
        return try await acceptConsents(request)
    }
}

private struct TestKakaoLoginService: KakaoLoginServicing {
    var credential = KakaoOIDCCredential(
        idToken: "kakao-id-token",
        nonce: "nonce",
        kakaoAccessToken: "kakao-access-token"
    )

    func login() async throws -> KakaoOIDCCredential {
        credential
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
            profileImageUrl: member.profileImageUrl,
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
