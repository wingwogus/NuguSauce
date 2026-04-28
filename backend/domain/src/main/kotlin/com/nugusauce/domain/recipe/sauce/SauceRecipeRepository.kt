package com.nugusauce.domain.recipe.sauce

import org.springframework.data.jpa.repository.JpaRepository

interface SauceRecipeRepository : JpaRepository<SauceRecipe, Long> {
    fun findAllByVisibility(visibility: RecipeVisibility): List<SauceRecipe>
    fun findAllByAuthorIdOrderByCreatedAtDesc(authorId: Long): List<SauceRecipe>
    fun findAllByAuthorIdAndVisibilityOrderByCreatedAtDesc(
        authorId: Long,
        visibility: RecipeVisibility
    ): List<SauceRecipe>
}
