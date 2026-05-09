package com.nugusauce.domain.recipe.sauce

import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.Instant

interface SauceRecipeRepository : JpaRepository<SauceRecipe, Long>, SauceRecipeQueryRepository {
    fun findAllByVisibility(visibility: RecipeVisibility): List<SauceRecipe>
    fun findAllByAuthorIdAndVisibilityOrderByCreatedAtDesc(
        authorId: Long,
        visibility: RecipeVisibility
    ): List<SauceRecipe>
    fun findByIdAndAuthorId(recipeId: Long, authorId: Long): SauceRecipe?

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(
        """
        update SauceRecipe r
        set r.favoriteCount = r.favoriteCount + 1,
            r.updatedAt = :updatedAt
        where r.id = :recipeId
        """
    )
    fun incrementFavoriteCount(
        @Param("recipeId") recipeId: Long,
        @Param("updatedAt") updatedAt: Instant
    ): Int

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(
        """
        update SauceRecipe r
        set r.favoriteCount = case
                when r.favoriteCount > 0 then r.favoriteCount - 1
                else 0
            end,
            r.updatedAt = :updatedAt
        where r.id = :recipeId
        """
    )
    fun decrementFavoriteCount(
        @Param("recipeId") recipeId: Long,
        @Param("updatedAt") updatedAt: Instant
    ): Int
}
