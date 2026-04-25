package com.nugusauce.domain.recipe.favorite

import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param

interface RecipeFavoriteRepository : JpaRepository<RecipeFavorite, Long> {
    @Query(
        """
        select case when count(f) > 0 then true else false end
        from RecipeFavorite f
        where f.recipe.id = :recipeId and f.member.id = :memberId
        """
    )
    fun existsByRecipeAndMember(
        @Param("recipeId") recipeId: Long,
        @Param("memberId") memberId: Long
    ): Boolean

    @Query(
        """
        select f
        from RecipeFavorite f
        where f.member.id = :memberId
        order by f.createdAt desc
        """
    )
    fun findAllByMemberIdOrderByCreatedAtDesc(
        @Param("memberId") memberId: Long
    ): List<RecipeFavorite>

    @Query(
        """
        select f
        from RecipeFavorite f
        where f.recipe.id = :recipeId and f.member.id = :memberId
        """
    )
    fun findByRecipeAndMember(
        @Param("recipeId") recipeId: Long,
        @Param("memberId") memberId: Long
    ): RecipeFavorite?
}
