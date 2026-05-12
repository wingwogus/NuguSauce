package com.nugusauce.domain.recipe.sauce

interface SauceRecipeQueryRepository {
    fun searchRecipePage(condition: SauceRecipePageCondition): SauceRecipePageSlice
    fun searchHomeSections(condition: SauceRecipeHomeCondition): SauceRecipeHomeSections
}

data class SauceRecipePageCondition(
    val keyword: String? = null,
    val tagIds: Set<Long> = emptySet(),
    val ingredientIds: Set<Long> = emptySet(),
    val sort: SauceRecipeSort = SauceRecipeSort.POPULAR,
    val limit: Int,
    val offset: Long = 0
)

data class SauceRecipePageSlice(
    val recipes: List<SauceRecipe>,
    val hasNext: Boolean
)

data class SauceRecipeHomeCondition(
    val popularLimit: Int,
    val recentLimit: Int
)

data class SauceRecipeHomeSections(
    val popular: List<SauceRecipe>,
    val recent: List<SauceRecipe>
)

enum class SauceRecipeSort {
    POPULAR,
    RECENT
}
