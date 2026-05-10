package com.nugusauce.application.recipe

import com.nugusauce.application.member.MemberResult
import com.nugusauce.domain.recipe.favorite.RecipeFavorite
import com.nugusauce.domain.recipe.ingredient.Ingredient
import com.nugusauce.domain.recipe.ingredient.RecipeIngredient
import com.nugusauce.domain.recipe.report.RecipeReport
import com.nugusauce.domain.recipe.review.RecipeReview
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.tag.RecipeTag
import java.math.BigDecimal
import java.time.Instant

object RecipeResult {
    data class IngredientItem(
        val id: Long,
        val name: String,
        val category: String?
    )

    data class TagItem(
        val id: Long,
        val name: String
    )

    data class RecipeIngredientItem(
        val ingredientId: Long,
        val name: String,
        val amount: BigDecimal?,
        val unit: String?,
        val ratio: BigDecimal?
    )

    data class RatingSummary(
        val averageRating: Double,
        val reviewCount: Int
    )

    data class RecipeSummary(
        val id: Long,
        val title: String,
        val description: String,
        val spiceLevel: Int,
        val richnessLevel: Int,
        val imageUrl: String?,
        val visibility: String,
        val ratingSummary: RatingSummary,
        val tags: List<TagItem>,
        val favoriteCount: Int = 0,
        val isFavorite: Boolean = false,
        val createdAt: Instant
    )

    data class RecipeDetail(
        val id: Long,
        val title: String,
        val description: String,
        val spiceLevel: Int,
        val richnessLevel: Int,
        val imageUrl: String?,
        val tips: String?,
        val authorId: Long?,
        val authorName: String,
        val authorProfileImageUrl: String?,
        val visibility: String,
        val ingredients: List<RecipeIngredientItem>,
        val tags: List<TagItem>,
        val ratingSummary: RatingSummary,
        val favoriteCount: Int = 0,
        val isFavorite: Boolean,
        val createdAt: Instant,
        val lastReviewedAt: Instant?
    )

    data class ReviewItem(
        val id: Long,
        val recipeId: Long,
        val authorId: Long,
        val authorName: String,
        val authorProfileImageUrl: String?,
        val rating: Int,
        val text: String?,
        val createdAt: Instant
    )

    data class ReportItem(
        val id: Long,
        val recipeId: Long,
        val reason: String,
        val createdAt: Instant
    )

    data class FavoriteItem(
        val recipeId: Long,
        val createdAt: Instant
    )

    fun fromIngredient(ingredient: Ingredient): IngredientItem {
        return IngredientItem(
            id = ingredient.id,
            name = ingredient.name,
            category = ingredient.category
        )
    }

    fun fromTag(tag: RecipeTag): TagItem {
        return TagItem(
            id = tag.id,
            name = tag.name
        )
    }

    fun fromRecipeIngredient(recipeIngredient: RecipeIngredient): RecipeIngredientItem {
        return RecipeIngredientItem(
            ingredientId = recipeIngredient.ingredient.id,
            name = recipeIngredient.ingredient.name,
            amount = recipeIngredient.amount,
            unit = recipeIngredient.unit,
            ratio = recipeIngredient.ratio
        )
    }

    fun summary(
        recipe: SauceRecipe,
        isFavorite: Boolean = false,
        imageUrl: String? = recipe.imageUrl
    ): RecipeSummary {
        return RecipeSummary(
            id = recipe.id,
            title = recipe.title,
            description = recipe.description,
            spiceLevel = recipe.spiceLevel,
            richnessLevel = recipe.richnessLevel,
            imageUrl = imageUrl,
            visibility = recipe.visibility.name,
            ratingSummary = RatingSummary(recipe.averageRating, recipe.reviewCount),
            tags = sortedTags(recipe),
            favoriteCount = recipe.favoriteCount,
            isFavorite = isFavorite,
            createdAt = recipe.createdAt
        )
    }

    fun detail(
        recipe: SauceRecipe,
        isFavorite: Boolean = false,
        imageUrl: String? = recipe.imageUrl,
        authorProfileImageUrl: String? = null
    ): RecipeDetail {
        return RecipeDetail(
            id = recipe.id,
            title = recipe.title,
            description = recipe.description,
            spiceLevel = recipe.spiceLevel,
            richnessLevel = recipe.richnessLevel,
            imageUrl = imageUrl,
            tips = recipe.tips,
            authorId = recipe.author?.id,
            authorName = authorName(recipe),
            authorProfileImageUrl = authorProfileImageUrl,
            visibility = recipe.visibility.name,
            ingredients = recipe.ingredients.map(::fromRecipeIngredient).sortedBy { it.name },
            tags = sortedTags(recipe),
            ratingSummary = RatingSummary(recipe.averageRating, recipe.reviewCount),
            favoriteCount = recipe.favoriteCount,
            isFavorite = isFavorite,
            createdAt = recipe.createdAt,
            lastReviewedAt = recipe.lastReviewedAt
        )
    }

    fun review(review: RecipeReview, authorProfileImageUrl: String? = null): ReviewItem {
        return ReviewItem(
            id = review.id,
            recipeId = review.recipe.id,
            authorId = review.author.id,
            authorName = MemberResult.displayName(review.author),
            authorProfileImageUrl = authorProfileImageUrl,
            rating = review.rating,
            text = review.text,
            createdAt = review.createdAt
        )
    }

    fun report(report: RecipeReport): ReportItem {
        return ReportItem(
            id = report.id,
            recipeId = report.recipe.id,
            reason = report.reason,
            createdAt = report.createdAt
        )
    }

    fun favorite(favorite: RecipeFavorite): FavoriteItem {
        return FavoriteItem(
            recipeId = favorite.recipe.id,
            createdAt = favorite.createdAt
        )
    }

    private fun authorName(recipe: SauceRecipe): String {
        return recipe.author?.let(MemberResult::displayName) ?: "NuguSauce"
    }

    private fun sortedTags(recipe: SauceRecipe): List<TagItem> {
        return recipe.tags
            .map(::fromTag)
            .sortedBy { RecipeTagDerivationPolicy.canonicalOrderIndex(it.name) }
    }
}
