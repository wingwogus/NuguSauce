import Foundation

protocol CacheControllingAPIClient: AnyObject {
    func invalidate(scope: CacheInvalidationScope) async
}

enum CacheInvalidationScope: Equatable {
    case all
    case viewerRelative
    case recipeLists
    case recipeDetail(Int)
    case reviews(Int)
    case favorites
    case profile
    case masterData
}

struct RecipeListCacheKey: Hashable {
    let keyword: String?
    let tagIDs: [Int]
    let ingredientIDs: [Int]
    let sort: RecipeSort

    init(query: RecipeListQuery) {
        let trimmedKeyword = query.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        keyword = trimmedKeyword.isEmpty ? nil : trimmedKeyword
        tagIDs = query.tagIDs.sorted()
        ingredientIDs = query.ingredientIDs.sorted()
        sort = query.sort
    }
}

enum CacheBucket: Hashable {
    case anonymous
    case member(Int)
    case ephemeralAuthenticatedWithoutMember
}

final class CachingAPIClient: APIClientProtocol, CacheControllingAPIClient {
    private let upstream: APIClientProtocol
    private let authStore: AuthSessionStoreProtocol
    private let cache: APIResponseCache

    init(
        upstream: APIClientProtocol,
        authStore: AuthSessionStoreProtocol,
        now: @escaping () -> Date = Date.init
    ) {
        self.upstream = upstream
        self.authStore = authStore
        self.cache = APIResponseCache(now: now)
    }

    func invalidate(scope: CacheInvalidationScope) async {
        let bucket = currentBucket()
        await cache.handleBucketIfChanged(bucket)
        await cache.invalidate(scope: scope)
    }

    func fetchRecipes(query: RecipeListQuery) async throws -> [RecipeSummaryDTO] {
        let capturedBucket = await prepareBucketForAccess()
        let cacheKey = APIResponseCacheKey.recipes(capturedBucket, RecipeListCacheKey(query: query))
        if shouldCacheViewerRelative(bucket: capturedBucket),
           let cached: [RecipeSummaryDTO] = await cache.value(for: cacheKey) {
            return cached
        }

        let recipes = try await upstream.fetchRecipes(query: query)
        await storeIfBucketStillMatches(
            recipes,
            for: cacheKey,
            ttl: CacheTTL.recipeList,
            capturedBucket: capturedBucket,
            cacheable: shouldCacheViewerRelative(bucket: capturedBucket)
        )
        return recipes
    }

    func fetchRecipeDetail(id: Int) async throws -> RecipeDetailDTO {
        let capturedBucket = await prepareBucketForAccess()
        let cacheKey = APIResponseCacheKey.recipeDetail(capturedBucket, id)
        if shouldCacheViewerRelative(bucket: capturedBucket),
           let cached: RecipeDetailDTO = await cache.value(for: cacheKey) {
            return cached
        }

        let detail = try await upstream.fetchRecipeDetail(id: id)
        await storeIfBucketStillMatches(
            detail,
            for: cacheKey,
            ttl: CacheTTL.recipeDetail,
            capturedBucket: capturedBucket,
            cacheable: shouldCacheViewerRelative(bucket: capturedBucket)
        )
        return detail
    }

    func fetchReviews(recipeID: Int) async throws -> [RecipeReviewDTO] {
        let cacheKey = APIResponseCacheKey.reviews(recipeID)
        if let cached: [RecipeReviewDTO] = await cache.value(for: cacheKey) {
            return cached
        }

        let reviews = try await upstream.fetchReviews(recipeID: recipeID)
        await cache.store(reviews, for: cacheKey, ttl: CacheTTL.reviews)
        return reviews
    }

    func fetchIngredients() async throws -> [IngredientDTO] {
        let cacheKey = APIResponseCacheKey.masterData(.ingredients)
        if let cached: [IngredientDTO] = await cache.value(for: cacheKey) {
            return cached
        }

        let ingredients = try await upstream.fetchIngredients()
        await cache.store(ingredients, for: cacheKey, ttl: CacheTTL.masterData)
        return ingredients
    }

    func fetchTags() async throws -> [TagDTO] {
        let cacheKey = APIResponseCacheKey.masterData(.tags)
        if let cached: [TagDTO] = await cache.value(for: cacheKey) {
            return cached
        }

        let tags = try await upstream.fetchTags()
        await cache.store(tags, for: cacheKey, ttl: CacheTTL.masterData)
        return tags
    }

    func createImageUploadIntent(_ request: ImageUploadIntentRequestDTO) async throws -> ImageUploadIntentDTO {
        try await upstream.createImageUploadIntent(request)
    }

    func uploadImage(
        data: Data,
        contentType: String,
        fileExtension: String,
        using intent: ImageUploadIntentDTO
    ) async throws {
        try await upstream.uploadImage(
            data: data,
            contentType: contentType,
            fileExtension: fileExtension,
            using: intent
        )
    }

    func completeImageUpload(imageId: Int) async throws -> VerifiedImageDTO {
        try await upstream.completeImageUpload(imageId: imageId)
    }

    func createRecipe(_ request: CreateRecipeRequestDTO) async throws -> RecipeDetailDTO {
        let recipe = try await upstream.createRecipe(request)
        await invalidate(scopes: [.recipeLists, .profile])
        return recipe
    }

    func updateRecipe(id: Int, request: UpdateRecipeRequestDTO) async throws -> RecipeDetailDTO {
        let recipe = try await upstream.updateRecipe(id: id, request: request)
        await invalidateRecipeMutationAffectedReads(recipeID: id)
        return recipe
    }

    func deleteRecipe(id: Int) async throws {
        try await upstream.deleteRecipe(id: id)
        await invalidateRecipeMutationAffectedReads(recipeID: id)
    }

    func createReview(recipeID: Int, request: CreateReviewRequestDTO) async throws -> RecipeReviewDTO {
        let review = try await upstream.createReview(recipeID: recipeID, request: request)
        await invalidate(scopes: [.reviews(recipeID), .recipeDetail(recipeID), .recipeLists])
        return review
    }

    func fetchMyRecipes() async throws -> [RecipeSummaryDTO] {
        let capturedBucket = await prepareBucketForAccess()
        let cacheKey = APIResponseCacheKey.myRecipes(capturedBucket)
        if shouldCachePrivate(bucket: capturedBucket),
           let cached: [RecipeSummaryDTO] = await cache.value(for: cacheKey) {
            return cached
        }

        let recipes = try await upstream.fetchMyRecipes()
        await storeIfBucketStillMatches(
            recipes,
            for: cacheKey,
            ttl: CacheTTL.privateRead,
            capturedBucket: capturedBucket,
            cacheable: shouldCachePrivate(bucket: capturedBucket)
        )
        return recipes
    }

    func fetchFavoriteRecipes() async throws -> [RecipeSummaryDTO] {
        let capturedBucket = await prepareBucketForAccess()
        let cacheKey = APIResponseCacheKey.favorites(capturedBucket)
        if shouldCachePrivate(bucket: capturedBucket),
           let cached: [RecipeSummaryDTO] = await cache.value(for: cacheKey) {
            return cached
        }

        let recipes = try await upstream.fetchFavoriteRecipes()
        await storeIfBucketStillMatches(
            recipes,
            for: cacheKey,
            ttl: CacheTTL.privateRead,
            capturedBucket: capturedBucket,
            cacheable: shouldCachePrivate(bucket: capturedBucket)
        )
        return recipes
    }

    func addFavorite(recipeID: Int) async throws -> FavoriteResponseDTO {
        do {
            let favorite = try await upstream.addFavorite(recipeID: recipeID)
            await invalidateFavoriteAffectedReads(recipeID: recipeID)
            return favorite
        } catch let error as ApiError where error.code == ApiErrorCode.duplicateFavorite {
            await invalidateFavoriteAffectedReads(recipeID: recipeID)
            throw error
        }
    }

    func deleteFavorite(recipeID: Int) async throws {
        do {
            try await upstream.deleteFavorite(recipeID: recipeID)
            await invalidateFavoriteAffectedReads(recipeID: recipeID)
        } catch let error as ApiError where error.code == ApiErrorCode.favoriteNotFound {
            await invalidateFavoriteAffectedReads(recipeID: recipeID)
            throw error
        }
    }

    func fetchMyMember() async throws -> MemberProfileDTO {
        let capturedBucket = await prepareBucketForAccess()
        let cacheKey = APIResponseCacheKey.myMember(capturedBucket)
        if shouldCachePrivate(bucket: capturedBucket),
           let cached: MemberProfileDTO = await cache.value(for: cacheKey) {
            return cached
        }

        let member = try await upstream.fetchMyMember()
        await storeIfBucketStillMatches(
            member,
            for: cacheKey,
            ttl: CacheTTL.privateRead,
            capturedBucket: capturedBucket,
            cacheable: shouldCachePrivate(bucket: capturedBucket)
        )
        return member
    }

    func fetchMember(id: Int) async throws -> MemberProfileDTO {
        try await upstream.fetchMember(id: id)
    }

    func updateMyMember(nickname: String, profileImageId: Int?) async throws -> MemberProfileDTO {
        let member = try await upstream.updateMyMember(nickname: nickname, profileImageId: profileImageId)
        await invalidate(scopes: [.profile, .recipeLists, .favorites])
        return member
    }

    func updateMyMember(nickname: String, profileImageId: Int?, accessToken: String) async throws -> MemberProfileDTO {
        let member = try await upstream.updateMyMember(
            nickname: nickname,
            profileImageId: profileImageId,
            accessToken: accessToken
        )
        await invalidate(scopes: [.profile, .recipeLists, .favorites])
        return member
    }

    func authenticateWithKakao(idToken: String, nonce: String, kakaoAccessToken: String) async throws -> KakaoLoginResponseDTO {
        try await upstream.authenticateWithKakao(idToken: idToken, nonce: nonce, kakaoAccessToken: kakaoAccessToken)
    }

    func reissue(refreshToken: String) async throws -> TokenResponseDTO {
        try await upstream.reissue(refreshToken: refreshToken)
    }

    func fetchConsentStatus() async throws -> ConsentStatusDTO {
        try await upstream.fetchConsentStatus()
    }

    func fetchConsentStatus(accessToken: String) async throws -> ConsentStatusDTO {
        try await upstream.fetchConsentStatus(accessToken: accessToken)
    }

    func acceptConsents(_ request: ConsentAcceptRequestDTO) async throws -> ConsentStatusDTO {
        try await upstream.acceptConsents(request)
    }

    func acceptConsents(_ request: ConsentAcceptRequestDTO, accessToken: String) async throws -> ConsentStatusDTO {
        try await upstream.acceptConsents(request, accessToken: accessToken)
    }

    private func invalidateFavoriteAffectedReads(recipeID: Int) async {
        await invalidate(scopes: [.recipeDetail(recipeID), .recipeLists, .favorites, .profile])
    }

    private func invalidateRecipeMutationAffectedReads(recipeID: Int) async {
        await invalidate(scopes: [.recipeDetail(recipeID), .recipeLists, .favorites, .profile])
    }

    private func invalidate(scopes: [CacheInvalidationScope]) async {
        let bucket = currentBucket()
        await cache.handleBucketIfChanged(bucket)
        for scope in scopes {
            await cache.invalidate(scope: scope)
        }
    }

    private func prepareBucketForAccess() async -> CacheBucket {
        let bucket = currentBucket()
        await cache.handleBucketIfChanged(bucket)
        return bucket
    }

    private func currentBucket() -> CacheBucket {
        guard let session = authStore.currentSession else {
            return .anonymous
        }
        guard let memberId = session.memberId else {
            return .ephemeralAuthenticatedWithoutMember
        }
        return .member(memberId)
    }

    private func shouldCacheViewerRelative(bucket: CacheBucket) -> Bool {
        bucket != .ephemeralAuthenticatedWithoutMember
    }

    private func shouldCachePrivate(bucket: CacheBucket) -> Bool {
        if case .member = bucket {
            return true
        }
        return false
    }

    private func storeIfBucketStillMatches<Value>(
        _ value: Value,
        for key: APIResponseCacheKey,
        ttl: TimeInterval,
        capturedBucket: CacheBucket,
        cacheable: Bool
    ) async {
        guard cacheable else {
            return
        }

        let latestBucket = currentBucket()
        await cache.handleBucketIfChanged(latestBucket)
        guard latestBucket == capturedBucket else {
            return
        }

        await cache.store(value, for: key, ttl: ttl)
    }
}

private enum CacheTTL {
    static let masterData: TimeInterval = 30 * 60
    static let recipeList: TimeInterval = 60
    static let recipeDetail: TimeInterval = 60
    static let reviews: TimeInterval = 60
    static let privateRead: TimeInterval = 30
}

private enum MasterDataCacheKey: Hashable {
    case ingredients
    case tags
}

private enum APIResponseCacheKey: Hashable {
    case masterData(MasterDataCacheKey)
    case recipes(CacheBucket, RecipeListCacheKey)
    case recipeDetail(CacheBucket, Int)
    case reviews(Int)
    case favorites(CacheBucket)
    case myRecipes(CacheBucket)
    case myMember(CacheBucket)
}

private actor APIResponseCache {
    private struct Entry {
        let value: Any
        let expiresAt: Date
    }

    private var entries: [APIResponseCacheKey: Entry] = [:]
    private var lastBucket: CacheBucket?
    private let now: () -> Date

    init(now: @escaping () -> Date) {
        self.now = now
    }

    func handleBucketIfChanged(_ bucket: CacheBucket) {
        guard let previousBucket = lastBucket else {
            lastBucket = bucket
            return
        }

        guard previousBucket != bucket else {
            return
        }

        removeViewerRelativeAndPrivateEntries()
        lastBucket = bucket
    }

    func value<Value>(for key: APIResponseCacheKey) -> Value? {
        guard let entry = entries[key] else {
            return nil
        }

        guard entry.expiresAt > now() else {
            entries.removeValue(forKey: key)
            return nil
        }

        return entry.value as? Value
    }

    func store<Value>(_ value: Value, for key: APIResponseCacheKey, ttl: TimeInterval) {
        entries[key] = Entry(value: value, expiresAt: now().addingTimeInterval(ttl))
    }

    func invalidate(scope: CacheInvalidationScope) {
        switch scope {
        case .all:
            entries.removeAll()
            lastBucket = nil
        case .viewerRelative:
            removeViewerRelativeAndPrivateEntries()
        case .recipeLists:
            removeEntries { key in
                if case .recipes = key {
                    return true
                }
                return false
            }
        case .recipeDetail(let id):
            removeEntries { key in
                if case .recipeDetail(_, let cachedID) = key {
                    return cachedID == id
                }
                return false
            }
        case .reviews(let recipeID):
            entries.removeValue(forKey: .reviews(recipeID))
        case .favorites:
            removeEntries { key in
                if case .favorites = key {
                    return true
                }
                return false
            }
        case .profile:
            removeEntries { key in
                switch key {
                case .myRecipes, .myMember:
                    return true
                default:
                    return false
                }
            }
        case .masterData:
            removeEntries { key in
                if case .masterData = key {
                    return true
                }
                return false
            }
        }
    }

    private func removeViewerRelativeAndPrivateEntries() {
        removeEntries { key in
            switch key {
            case .recipes, .recipeDetail, .favorites, .myRecipes, .myMember:
                return true
            case .masterData, .reviews:
                return false
            }
        }
    }

    private func removeEntries(where shouldRemove: (APIResponseCacheKey) -> Bool) {
        for key in entries.keys where shouldRemove(key) {
            entries.removeValue(forKey: key)
        }
    }
}
