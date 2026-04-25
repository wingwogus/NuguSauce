import Foundation

enum AuthorType: String, Codable, Equatable {
    case curated = "CURATED"
    case user = "USER"
}

enum RecipeVisibility: String, Codable, Equatable {
    case visible = "VISIBLE"
    case hidden = "HIDDEN"
}

struct RatingSummaryDTO: Codable, Equatable {
    let averageRating: Double
    let reviewCount: Int
}

struct ReviewTagDTO: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let count: Int?
}

struct RecipeIngredientDTO: Codable, Identifiable, Equatable {
    var id: Int { ingredientId }
    let ingredientId: Int
    let name: String
    let amount: Double?
    let unit: String?
    let ratio: Double?
}

struct RecipeSummaryDTO: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String
    let imageUrl: String?
    let authorType: AuthorType
    let visibility: RecipeVisibility
    let ratingSummary: RatingSummaryDTO
    let reviewTags: [ReviewTagDTO]
    let createdAt: String
}

struct RecipeDetailDTO: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String
    let imageUrl: String?
    let tips: String?
    let authorType: AuthorType
    let visibility: RecipeVisibility
    let ingredients: [RecipeIngredientDTO]
    let reviewTags: [ReviewTagDTO]
    let ratingSummary: RatingSummaryDTO
    let createdAt: String
    let lastReviewedAt: String?
}

struct RecipeReviewDTO: Codable, Identifiable, Equatable {
    let id: Int
    let recipeId: Int
    let rating: Int
    let text: String?
    let tasteTags: [ReviewTagDTO]
    let createdAt: String
}

struct IngredientDTO: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let category: String?
}

struct TagDTO: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
}

struct CreateRecipeIngredientRequestDTO: Codable, Equatable {
    let ingredientId: Int
    let amount: Double?
    let unit: String?
    let ratio: Double?
}

struct CreateRecipeRequestDTO: Codable, Equatable {
    let title: String
    let description: String
    let imageUrl: String?
    let tips: String
    let ingredients: [CreateRecipeIngredientRequestDTO]
}

struct CreateReviewRequestDTO: Codable, Equatable {
    let rating: Int
    let text: String?
    let tasteTagIds: [Int]
}

struct FavoriteResponseDTO: Codable, Equatable {
    let recipeId: Int
    let createdAt: String
}
