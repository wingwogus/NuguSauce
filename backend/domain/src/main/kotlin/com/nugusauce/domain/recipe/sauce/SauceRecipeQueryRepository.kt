package com.nugusauce.domain.recipe.sauce

import java.time.Instant

interface SauceRecipeQueryRepository {
    fun searchVisibleRecipes(condition: SauceRecipeSearchCondition): List<SauceRecipe>
}

data class SauceRecipeSearchCondition(
    val keyword: String? = null,
    val tagIds: Set<Long> = emptySet(),
    val ingredientIds: Set<Long> = emptySet(),
    val sort: SauceRecipeSort = SauceRecipeSort.POPULAR,
    val hotSince: Instant? = null
)

enum class SauceRecipeSort {
    HOT,
    POPULAR,
    RECENT,
    RATING
}
