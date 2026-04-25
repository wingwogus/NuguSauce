import Foundation

struct ApiEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: ApiError?
}

struct EmptyResponse: Decodable, Equatable {}

struct ApiError: Decodable, Equatable, Error {
    let code: String
    let message: String
    let detail: String?
}

enum ApiErrorCode {
    static let unauthorized = "AUTH_001"
    static let invalidInput = "COMMON_001"
    static let duplicateReview = "RECIPE_005"
    static let duplicateFavorite = "RECIPE_010"
    static let favoriteNotFound = "RECIPE_011"
}

enum RecipeSort: String, CaseIterable, Identifiable {
    case popular
    case recent
    case rating

    var id: String { rawValue }

    var label: String {
        switch self {
        case .popular:
            return "인기순"
        case .recent:
            return "최신순"
        case .rating:
            return "평점순"
        }
    }
}

struct RecipeListQuery: Equatable {
    var keyword: String = ""
    var tagIDs: Set<Int> = []
    var ingredientIDs: Set<Int> = []
    var sort: RecipeSort = .popular
}

protocol APIClientProtocol {
    func fetchRecipes(query: RecipeListQuery) async throws -> [RecipeSummaryDTO]
    func fetchRecipeDetail(id: Int) async throws -> RecipeDetailDTO
    func fetchReviews(recipeID: Int) async throws -> [RecipeReviewDTO]
    func fetchIngredients() async throws -> [IngredientDTO]
    func fetchTags() async throws -> [TagDTO]
    func createRecipe(_ request: CreateRecipeRequestDTO) async throws -> RecipeDetailDTO
    func createReview(recipeID: Int, request: CreateReviewRequestDTO) async throws -> RecipeReviewDTO
    func fetchMyRecipes() async throws -> [RecipeSummaryDTO]
    func fetchFavoriteRecipes() async throws -> [RecipeSummaryDTO]
    func deleteFavorite(recipeID: Int) async throws
}
