package com.nugusauce.domain.recipe.report

import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param

interface RecipeReportRepository : JpaRepository<RecipeReport, Long> {
    @Query(
        """
        select case when count(r) > 0 then true else false end
        from RecipeReport r
        where r.recipe.id = :recipeId and r.reporter.id = :reporterId
        """
    )
    fun existsByRecipeAndReporter(
        @Param("recipeId") recipeId: Long,
        @Param("reporterId") reporterId: Long
    ): Boolean

    fun findAllByRecipeId(recipeId: Long): List<RecipeReport>
}
