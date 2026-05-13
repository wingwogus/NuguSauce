package com.nugusauce.domain.recipe.review

import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param

interface RecipeReviewRepository : JpaRepository<RecipeReview, Long> {
    @Query(
        """
        select case when count(r) > 0 then true else false end
        from RecipeReview r
        where r.recipe.id = :recipeId and r.author.id = :authorId
        """
    )
    fun existsByRecipeAndAuthor(
        @Param("recipeId") recipeId: Long,
        @Param("authorId") authorId: Long
    ): Boolean

    fun findAllByRecipeIdOrderByCreatedAtDesc(recipeId: Long): List<RecipeReview>

    fun findAllByRecipeId(recipeId: Long): List<RecipeReview>

    fun findAllByAuthorId(authorId: Long): List<RecipeReview>

}
