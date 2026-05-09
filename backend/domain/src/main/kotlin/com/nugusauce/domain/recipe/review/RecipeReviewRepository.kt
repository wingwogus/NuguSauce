package com.nugusauce.domain.recipe.review

import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param

interface RecipeReviewTagCountProjection {
    val recipeId: Long
    val tagId: Long
    val tagName: String
    val tagCount: Long
}

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

    @Query(
        """
        select r.recipe.id as recipeId,
               tag.id as tagId,
               tag.name as tagName,
               count(tag) as tagCount
        from RecipeReview r
        join r.tasteTags tag
        where r.recipe.id in :recipeIds
        group by r.recipe.id, tag.id, tag.name
        """
    )
    fun countTasteTagsByRecipeIds(
        @Param("recipeIds") recipeIds: Collection<Long>
    ): List<RecipeReviewTagCountProjection>
}
