package com.nugusauce.application.recipe

import java.math.BigDecimal

object RecipeCommand {
    enum class RecipeSort {
        HOT,
        POPULAR,
        RECENT,
        RATING;

        companion object {
            fun from(value: String?): RecipeSort {
                return when (value?.lowercase()) {
                    null, "", "popular" -> POPULAR
                    "hot" -> HOT
                    "recent" -> RECENT
                    "rating" -> RATING
                    else -> throw IllegalArgumentException("unsupported recipe sort: $value")
                }
            }
        }
    }

    enum class Visibility {
        VISIBLE,
        HIDDEN;

        companion object {
            fun from(value: String): Visibility {
                return entries.firstOrNull { it.name == value.uppercase() }
                    ?: throw IllegalArgumentException("unsupported visibility: $value")
            }
        }
    }

    data class SearchRecipes(
        val q: String? = null,
        val tagIds: List<Long> = emptyList(),
        val ingredientIds: List<Long> = emptyList(),
        val sort: RecipeSort = RecipeSort.POPULAR,
        val viewerMemberId: Long? = null
    )

    data class IngredientInput(
        val ingredientId: Long,
        val amount: BigDecimal? = null,
        val unit: String? = null,
        val ratio: BigDecimal? = null
    )

    data class CreateRecipe(
        val authorId: Long,
        val title: String,
        val description: String,
        val imageId: Long? = null,
        val tips: String? = null,
        val ingredients: List<IngredientInput>
    )

    data class CreateReview(
        val authorId: Long,
        val recipeId: Long,
        val rating: Int,
        val text: String? = null,
        val tasteTagIds: List<Long> = emptyList()
    )

    data class CreateReport(
        val reporterId: Long,
        val recipeId: Long,
        val reason: String
    )

    data class UpdateVisibility(
        val recipeId: Long,
        val visibility: Visibility
    )

    data class MemberRecipes(
        val memberId: Long
    )

    data class FavoriteRecipe(
        val memberId: Long,
        val recipeId: Long
    )
}
