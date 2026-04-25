import Foundation

struct ApiEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: ApiError?
}

struct EmptyResponse: Decodable, Equatable {
    init() {}
}

struct ApiError: Decodable, Equatable, Error {
    let code: String
    let message: String
    let detail: String?

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case detail
    }

    init(code: String, message: String, detail: String?) {
        self.code = code
        self.message = message
        self.detail = detail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        message = try container.decode(String.self, forKey: .message)
        do {
            detail = try container.decodeIfPresent(String.self, forKey: .detail)
        } catch {
            detail = nil
        }
    }
}

enum ApiErrorCode {
    static let unauthorized = "AUTH_001"
    static let invalidKakaoToken = "AUTH_009"
    static let kakaoNonceMismatch = "AUTH_010"
    static let kakaoNonceReplay = "AUTH_011"
    static let kakaoVerifiedEmailRequired = "AUTH_012"
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

struct TokenResponseDTO: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
}

enum APIClientError: Error, Equatable {
    case invalidBaseURL(String)
    case invalidURL
    case invalidResponse
    case missingAuthentication
    case missingData
    case unsuccessfulEnvelope
    case httpStatus(Int)
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
    func addFavorite(recipeID: Int) async throws -> FavoriteResponseDTO
    func deleteFavorite(recipeID: Int) async throws
    func authenticateWithKakao(idToken: String, nonce: String, kakaoAccessToken: String) async throws -> TokenResponseDTO
    func reissue(refreshToken: String) async throws -> TokenResponseDTO
}
