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

    data class RecipeSummaryResponse(
        val id: Long,
        val title: String,
        val description: String,
        val imageUrl: String?,
        val visibility: String,
        val ratingSummary: RatingSummaryResponse,
        val tags: List<TagResponse>,
        val favoriteCount: Int,
        val isFavorite: Boolean,
        val createdAt: Instant
    ) {
        companion object {
            fun from(result: RecipeResult.RecipeSummary): RecipeSummaryResponse {
                return RecipeSummaryResponse(
                    id = result.id,
                    title = result.title,
                    description = result.description,
                    imageUrl = result.imageUrl,
                    visibility = result.visibility,
                    ratingSummary = RatingSummaryResponse.from(result.ratingSummary),
                    tags = result.tags.map(TagResponse::from),
                    favoriteCount = result.favoriteCount,
                    isFavorite = result.isFavorite,
                    createdAt = result.createdAt
                )
            }
        }
    }

    data class RecipeSearchPageResponse(
        val items: List<RecipeSummaryResponse>,
        val nextCursor: String?,
        val hasNext: Boolean
    ) {
        companion object {
            fun from(result: RecipeResult.RecipeSearchPage): RecipeSearchPageResponse {
                return RecipeSearchPageResponse(
                    items = result.items.map(RecipeSummaryResponse::from),
                    nextCursor = result.nextCursor,
                    hasNext = result.hasNext
                )
            }
        }
    }

    data class HomeResponse(
        val popularTop: List<RecipeSummaryResponse>,
        val recentTop: List<RecipeSummaryResponse>
    ) {
        companion object {
            fun from(result: RecipeResult.HomeFeed): HomeResponse {
                return HomeResponse(
                    popularTop = result.popularTop.map(RecipeSummaryResponse::from),
                    recentTop = result.recentTop.map(RecipeSummaryResponse::from)
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
        val authorId: Long?,
        val authorName: String,
        val authorProfileImageUrl: String?,
        val visibility: String,
        val ingredients: List<RecipeIngredientResponse>,
        val tags: List<TagResponse>,
        val ratingSummary: RatingSummaryResponse,
        val favoriteCount: Int,
        val isFavorite: Boolean,
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
                    authorId = result.authorId,
                    authorName = result.authorName,
                    authorProfileImageUrl = result.authorProfileImageUrl,
                    visibility = result.visibility,
                    ingredients = result.ingredients.map(RecipeIngredientResponse::from),
                    tags = result.tags.map(TagResponse::from),
                    ratingSummary = RatingSummaryResponse.from(result.ratingSummary),
                    favoriteCount = result.favoriteCount,
                    isFavorite = result.isFavorite,
                    createdAt = result.createdAt,
                    lastReviewedAt = result.lastReviewedAt
                )
            }
        }
    }

    data class ReviewResponse(
        val id: Long,
        val recipeId: Long,
        val authorId: Long,
        val authorName: String,
        val authorProfileImageUrl: String?,
        val rating: Int,
        val text: String?,
        val createdAt: Instant
    ) {
        companion object {
            fun from(result: RecipeResult.ReviewItem): ReviewResponse {
                return ReviewResponse(
                    id = result.id,
                    recipeId = result.recipeId,
                    authorId = result.authorId,
                    authorName = result.authorName,
                    authorProfileImageUrl = result.authorProfileImageUrl,
                    rating = result.rating,
                    text = result.text,
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
