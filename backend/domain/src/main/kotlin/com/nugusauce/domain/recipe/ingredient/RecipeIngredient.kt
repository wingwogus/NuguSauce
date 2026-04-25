package com.nugusauce.domain.recipe.ingredient

import com.nugusauce.domain.recipe.sauce.SauceRecipe
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import java.math.BigDecimal

@Entity
@Table(name = "recipe_ingredient")
class RecipeIngredient(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "recipe_id", nullable = false)
    val recipe: SauceRecipe,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "ingredient_id", nullable = false)
    val ingredient: Ingredient,

    @Column(nullable = true, precision = 10, scale = 2)
    val amount: BigDecimal? = null,

    @Column(nullable = true, length = 32)
    val unit: String? = null,

    @Column(nullable = true, precision = 10, scale = 2)
    val ratio: BigDecimal? = null
)
