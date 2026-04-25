import Foundation

actor MockAPIClient: APIClientProtocol {
    private let store: FixtureStore
    private var createdRecipes: [FixtureRecipeSeed] = []
    private var createdReviews: [RecipeReviewDTO] = []

    init(store: FixtureStore = .preview) {
        self.store = store
    }

    func fetchRecipes(query: RecipeListQuery) async throws -> [RecipeSummaryDTO] {
        let recipes = allSeeds()
            .filter { $0.visibility == .visible }
            .filter { seed in
                query.keyword.isEmpty ||
                seed.title.localizedCaseInsensitiveContains(query.keyword) ||
                seed.description.localizedCaseInsensitiveContains(query.keyword) ||
                seed.tips.localizedCaseInsensitiveContains(query.keyword)
            }
            .filter { seed in
                query.tagIDs.isEmpty || !query.tagIDs.isDisjoint(with: Set(seed.tagIDs))
            }
            .filter { seed in
                query.ingredientIDs.isEmpty ||
                !query.ingredientIDs.isDisjoint(with: Set(seed.ingredientSeeds.map(\.ingredientID)))
            }

        let summaries = recipes.map(summary)
        switch query.sort {
        case .popular:
            return summaries.sorted {
                if $0.ratingSummary.reviewCount == $1.ratingSummary.reviewCount {
                    return $0.ratingSummary.averageRating > $1.ratingSummary.averageRating
                }
                return $0.ratingSummary.reviewCount > $1.ratingSummary.reviewCount
            }
        case .recent:
            return summaries.sorted { $0.createdAt > $1.createdAt }
        case .rating:
            return summaries.sorted {
                if $0.ratingSummary.averageRating == $1.ratingSummary.averageRating {
                    return $0.ratingSummary.reviewCount > $1.ratingSummary.reviewCount
                }
                return $0.ratingSummary.averageRating > $1.ratingSummary.averageRating
            }
        }
    }

    func fetchRecipeDetail(id: Int) async throws -> RecipeDetailDTO {
        guard let seed = allSeeds().first(where: { $0.id == id }), seed.visibility == .visible else {
            throw ApiError(code: "RECIPE_001", message: "recipe.not_found", detail: nil)
        }

        return detail(seed)
    }

    func fetchReviews(recipeID: Int) async throws -> [RecipeReviewDTO] {
        (store.reviews + createdReviews)
            .filter { $0.recipeId == recipeID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchIngredients() async throws -> [IngredientDTO] {
        store.ingredients
    }

    func fetchTags() async throws -> [TagDTO] {
        store.tags
    }

    func createRecipe(_ request: CreateRecipeRequestDTO) async throws -> RecipeDetailDTO {
        guard !request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.ingredients.isEmpty else {
            throw ApiError(code: ApiErrorCode.invalidInput, message: "recipe.invalid_input", detail: nil)
        }

        let newID = 900 + createdRecipes.count
        let seed = FixtureRecipeSeed(
            id: newID,
            title: request.title,
            description: request.description,
            tips: request.tips,
            authorType: .user,
            visibility: .visible,
            tagIDs: [],
            ingredientSeeds: request.ingredients.map {
                FixtureIngredientAmount(ingredientID: $0.ingredientId, amount: $0.amount, unit: $0.unit, ratio: $0.ratio)
            },
            createdAt: "2026-04-25T03:00:00Z"
        )
        createdRecipes.append(seed)
        return detail(seed)
    }

    func createReview(recipeID: Int, request: CreateReviewRequestDTO) async throws -> RecipeReviewDTO {
        guard (1...5).contains(request.rating) else {
            throw ApiError(code: "RECIPE_007", message: "review.invalid_rating", detail: nil)
        }

        let tags = store.tags
            .filter { request.tasteTagIds.contains($0.id) }
            .map { ReviewTagDTO(id: $0.id, name: $0.name, count: nil) }
        let review = RecipeReviewDTO(
            id: 8_000 + createdReviews.count,
            recipeId: recipeID,
            rating: request.rating,
            text: request.text,
            tasteTags: tags,
            createdAt: "2026-04-25T04:00:00Z"
        )
        createdReviews.append(review)
        return review
    }

    func fetchMyRecipes() async throws -> [RecipeSummaryDTO] {
        (store.userRecipes + createdRecipes).map(summary)
    }

    func fetchFavoriteRecipes() async throws -> [RecipeSummaryDTO] {
        let favoriteIDs = Set(store.favorites.map(\.recipeID))
        return allSeeds()
            .filter { favoriteIDs.contains($0.id) && $0.visibility == .visible }
            .map(summary)
    }

    func deleteFavorite(recipeID: Int) async throws {}

    private func allSeeds() -> [FixtureRecipeSeed] {
        store.curatedRecipes + store.userRecipes + createdRecipes
    }

    private func summary(_ seed: FixtureRecipeSeed) -> RecipeSummaryDTO {
        RecipeSummaryDTO(
            id: seed.id,
            title: seed.title,
            description: seed.description,
            imageUrl: nil,
            authorType: seed.authorType,
            visibility: seed.visibility,
            ratingSummary: ratingSummary(recipeID: seed.id),
            reviewTags: reviewTags(seed),
            createdAt: seed.createdAt
        )
    }

    private func detail(_ seed: FixtureRecipeSeed) -> RecipeDetailDTO {
        RecipeDetailDTO(
            id: seed.id,
            title: seed.title,
            description: seed.description,
            imageUrl: nil,
            tips: seed.tips,
            authorType: seed.authorType,
            visibility: seed.visibility,
            ingredients: seed.ingredientSeeds.map(ingredient),
            reviewTags: reviewTags(seed),
            ratingSummary: ratingSummary(recipeID: seed.id),
            createdAt: seed.createdAt,
            lastReviewedAt: store.reviews.first(where: { $0.recipeId == seed.id })?.createdAt
        )
    }

    private func ingredient(_ amount: FixtureIngredientAmount) -> RecipeIngredientDTO {
        let ingredient = store.ingredients.first(where: { $0.id == amount.ingredientID })
        return RecipeIngredientDTO(
            ingredientId: amount.ingredientID,
            name: ingredient?.name ?? "재료",
            amount: amount.amount,
            unit: amount.unit,
            ratio: amount.ratio
        )
    }

    private func ratingSummary(recipeID: Int) -> RatingSummaryDTO {
        let recipeReviews = (store.reviews + createdReviews).filter { $0.recipeId == recipeID }
        guard !recipeReviews.isEmpty else {
            return RatingSummaryDTO(averageRating: 4.6, reviewCount: 0)
        }
        let total = recipeReviews.reduce(0) { $0 + $1.rating }
        return RatingSummaryDTO(
            averageRating: Double(total) / Double(recipeReviews.count),
            reviewCount: recipeReviews.count
        )
    }

    private func reviewTags(_ seed: FixtureRecipeSeed) -> [ReviewTagDTO] {
        store.tags
            .filter { seed.tagIDs.contains($0.id) }
            .map { ReviewTagDTO(id: $0.id, name: $0.name, count: seed.id + $0.id) }
    }
}
