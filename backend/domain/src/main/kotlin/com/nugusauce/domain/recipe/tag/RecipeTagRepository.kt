package com.nugusauce.domain.recipe.tag

import org.springframework.data.jpa.repository.JpaRepository

interface RecipeTagRepository : JpaRepository<RecipeTag, Long> {
    fun findAllByOrderByNameAsc(): List<RecipeTag>

    fun findAllByNameIn(names: Collection<String>): List<RecipeTag>
}
