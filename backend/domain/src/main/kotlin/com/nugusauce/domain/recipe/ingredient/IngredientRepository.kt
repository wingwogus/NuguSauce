package com.nugusauce.domain.recipe.ingredient

import org.springframework.data.jpa.repository.JpaRepository

interface IngredientRepository : JpaRepository<Ingredient, Long> {
    fun findAllByOrderByNameAsc(): List<Ingredient>
}
