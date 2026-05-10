import Foundation

enum RecipeVisibility: String, Codable, Equatable {
    case visible = "VISIBLE"
    case hidden = "HIDDEN"
}

struct RatingSummaryDTO: Codable, Equatable {
    let averageRating: Double
    let reviewCount: Int
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
    let visibility: RecipeVisibility
    let ratingSummary: RatingSummaryDTO
    let tags: [TagDTO]
    let favoriteCount: Int
    let isFavorite: Bool
    let createdAt: String

    var isFavorited: Bool {
        isFavorite
    }

    var displayFavoriteCount: Int {
        favoriteCount
    }

    var ratingReviewText: String {
        "\(RecipeMeasurementFormatter.oneDecimalText(ratingSummary.averageRating)) (\(ratingSummary.reviewCount))"
    }
}

struct RecipeDetailDTO: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String
    let imageUrl: String?
    let tips: String?
    let authorId: Int?
    let authorName: String?
    let authorProfileImageUrl: String?
    let visibility: RecipeVisibility
    let ingredients: [RecipeIngredientDTO]
    let tags: [TagDTO]
    let ratingSummary: RatingSummaryDTO
    let favoriteCount: Int
    let isFavorite: Bool?
    let createdAt: String
    let lastReviewedAt: String?

    var isFavorited: Bool {
        isFavorite ?? false
    }

    var displayFavoriteCount: Int {
        favoriteCount
    }

    var displayAuthorName: String? {
        let trimmedName = authorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedName, !trimmedName.isEmpty {
            return trimmedName
        }
        return nil
    }
}

struct RecipeReviewDTO: Codable, Identifiable, Equatable {
    let id: Int
    let recipeId: Int
    let authorId: Int?
    let authorName: String
    let authorProfileImageUrl: String?
    let rating: Int
    let text: String?
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
    let imageId: Int?
    let tips: String?
    let ingredients: [CreateRecipeIngredientRequestDTO]
}

struct UpdateRecipeRequestDTO: Codable, Equatable {
    let title: String
    let description: String
    let imageId: Int?
    let tips: String?
    let ingredients: [CreateRecipeIngredientRequestDTO]
}

enum RecipeMutationEvents {
    static let didUpdate = Notification.Name("NuguSauce.recipeDidUpdate")
    static let didDelete = Notification.Name("NuguSauce.recipeDidDelete")

    static let recipeIDKey = "recipeID"
    static let recipeKey = "recipe"
}

extension RecipeSummaryDTO {
    var tagTitles: [String] {
        tags.prefix(3).map(\.name)
    }

    init(detail: RecipeDetailDTO) {
        self.init(
            id: detail.id,
            title: detail.title,
            description: detail.description,
            imageUrl: detail.imageUrl,
            visibility: detail.visibility,
            ratingSummary: detail.ratingSummary,
            tags: detail.tags,
            favoriteCount: detail.favoriteCount,
            isFavorite: detail.isFavorited,
            createdAt: detail.createdAt
        )
    }
}

struct ImageUploadIntentRequestDTO: Codable, Equatable {
    let contentType: String
    let byteSize: Int
    let fileExtension: String?
}

struct ImageUploadIntentDTO: Codable, Equatable {
    let imageId: Int
    let upload: ImageUploadTargetDTO
    let constraints: ImageUploadConstraintsDTO
}

struct ImageUploadTargetDTO: Codable, Equatable {
    let url: String
    let method: String
    let headers: [String: String]
    let fields: [String: String]
    let fileField: String
    let expiresAt: String
}

struct ImageUploadConstraintsDTO: Codable, Equatable {
    let maxBytes: Int
    let allowedContentTypes: [String]
}

struct VerifiedImageDTO: Codable, Equatable {
    let imageId: Int
    let imageUrl: String
    let width: Int?
    let height: Int?
}

struct CreateReviewRequestDTO: Codable, Equatable {
    let rating: Int
    let text: String?
}

struct FavoriteResponseDTO: Codable, Equatable {
    let recipeId: Int
    let createdAt: String
}

enum RecipeMeasurementFormatter {
    static func truncatedTenths(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }

        var decimal = Decimal(value)
        var truncated = Decimal()
        NSDecimalRound(&truncated, &decimal, 1, .down)
        return NSDecimalNumber(decimal: truncated).doubleValue
    }

    static func oneDecimalText(_ value: Double?) -> String {
        String(format: "%.1f", truncatedTenths(value ?? 0))
    }
}
