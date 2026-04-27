package com.nugusauce.api.recipe

import com.nugusauce.application.recipe.RecipeResult
import java.math.BigDecimal
import java.time.Instant

object RecipeResponses {
    data class IngredientResponse(
        val id: Long,
        val name: String,
        val category: String?
    ) {
        companion object {
            fun from(result: RecipeResult.IngredientItem): IngredientResponse {
                return IngredientResponse(
                    id = result.id,
                    name = result.name,
                    category = result.category
                )
            }
        }
    }

    data class TagResponse(
        val id: Long,
        val name: String
    ) {
        companion object {
            fun from(result: RecipeResult.TagItem): TagResponse {
                return TagResponse(
                    id = result.id,
                    name = result.name
                )
            }
        }
    }

    data class RecipeIngredientResponse(
        val ingredientId: Long,
        val name: String,
        val amount: BigDecimal?,
        val unit: String?,
        val ratio: BigDecimal?
    ) {
        companion object {
            fun from(result: RecipeResult.RecipeIngredientItem): RecipeIngredientResponse {
                return RecipeIngredientResponse(
                    ingredientId = result.ingredientId,
                    name = result.name,
                    amount = result.amount,
                    unit = result.unit,
                    ratio = result.ratio
                )
            }
        }
    }

    data class RatingSummaryResponse(
        val averageRating: Double,
        val reviewCount: Int
    ) {
        companion object {
            fun from(result: RecipeResult.RatingSummary): RatingSummaryResponse {
                return RatingSummaryResponse(
                    averageRating = result.averageRating,
                    reviewCount = result.reviewCount
                )
            }
        }
    }

    data class ReviewTagCountResponse(
        val id: Long,
        val name: String,
        val count: Long
    ) {
        companion object {
            fun from(result: RecipeResult.ReviewTagCount): ReviewTagCountResponse {
                return ReviewTagCountResponse(
                    id = result.id,
                    name = result.name,
                    count = result.count
                )
            }
        }
    }

    data class RecipeSummaryResponse(
        val id: Long,
        val title: String,
        val description: String,
        val imageUrl: String?,
        val authorType: String,
        val visibility: String,
        val ratingSummary: RatingSummaryResponse,
        val reviewTags: List<ReviewTagCountResponse>,
        val createdAt: Instant
    ) {
        companion object {
            fun from(result: RecipeResult.RecipeSummary): RecipeSummaryResponse {
                return RecipeSummaryResponse(
                    id = result.id,
                    title = result.title,
                    description = result.description,
                    imageUrl = result.imageUrl,
                    authorType = result.authorType,
                    visibility = result.visibility,
                    ratingSummary = RatingSummaryResponse.from(result.ratingSummary),
                    reviewTags = result.reviewTags.map(ReviewTagCountResponse::from),
                    createdAt = result.createdAt
                )
            }
        }
    }

    data class RecipeDetailResponse(
        val id: Long,
        val title: String,
        val description: String,
        val imageUrl: String?,
        val tips: String?,
        val authorType: String,
        val visibility: String,
        val ingredients: List<RecipeIngredientResponse>,
        val reviewTags: List<ReviewTagCountResponse>,
        val ratingSummary: RatingSummaryResponse,
        val createdAt: Instant,
        val lastReviewedAt: Instant?
    ) {
        companion object {
            fun from(result: RecipeResult.RecipeDetail): RecipeDetailResponse {
                return RecipeDetailResponse(
                    id = result.id,
                    title = result.title,
                    description = result.description,
                    imageUrl = result.imageUrl,
                    tips = result.tips,
                    authorType = result.authorType,
                    visibility = result.visibility,
                    ingredients = result.ingredients.map(RecipeIngredientResponse::from),
                    reviewTags = result.reviewTags.map(ReviewTagCountResponse::from),
                    ratingSummary = RatingSummaryResponse.from(result.ratingSummary),
                    createdAt = result.createdAt,
                    lastReviewedAt = result.lastReviewedAt
                )
            }
        }
    }

    data class ReviewResponse(
        val id: Long,
        val recipeId: Long,
        val authorName: String,
        val rating: Int,
        val text: String?,
        val tasteTags: List<TagResponse>,
        val createdAt: Instant
    ) {
        companion object {
            fun from(result: RecipeResult.ReviewItem): ReviewResponse {
                return ReviewResponse(
                    id = result.id,
                    recipeId = result.recipeId,
                    authorName = result.authorName,
                    rating = result.rating,
                    text = result.text,
                    tasteTags = result.tasteTags.map(TagResponse::from),
                    createdAt = result.createdAt
                )
            }
        }
    }

    data class ReportResponse(
        val id: Long,
        val recipeId: Long,
        val reason: String,
        val createdAt: Instant
    ) {
        companion object {
            fun from(result: RecipeResult.ReportItem): ReportResponse {
                return ReportResponse(
                    id = result.id,
                    recipeId = result.recipeId,
                    reason = result.reason,
                    createdAt = result.createdAt
                )
            }
        }
    }

    data class FavoriteResponse(
        val recipeId: Long,
        val createdAt: Instant
    ) {
        companion object {
            fun from(result: RecipeResult.FavoriteItem): FavoriteResponse {
                return FavoriteResponse(
                    recipeId = result.recipeId,
                    createdAt = result.createdAt
                )
            }
        }
    }
}
