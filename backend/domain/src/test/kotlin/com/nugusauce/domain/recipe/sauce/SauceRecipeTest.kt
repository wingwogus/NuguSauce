package com.nugusauce.domain.recipe.sauce

import com.nugusauce.domain.member.Member
import com.nugusauce.domain.recipe.ingredient.Ingredient
import com.nugusauce.domain.recipe.tag.RecipeTag
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test
import java.math.BigDecimal

class SauceRecipeTest {
    private val author = Member(
        id = 1L,
        email = "user@example.test",
        passwordHash = null
    )

    @Test
    fun `recordReview updates rating summary deterministically`() {
        val recipe = userRecipe()

        recipe.recordReview(5)
        recipe.recordReview(3)

        assertEquals(2, recipe.reviewCount)
        assertEquals(4.0, recipe.averageRating)
    }

    @Test
    fun `recordReview rejects rating outside one to five`() {
        val recipe = userRecipe()

        assertThrows(IllegalArgumentException::class.java) {
            recipe.recordReview(0)
        }
    }

    @Test
    fun `addIngredient rejects missing amount and ratio`() {
        val recipe = userRecipe()
        val ingredient = Ingredient(id = 1L, name = "참기름")

        assertThrows(IllegalArgumentException::class.java) {
            recipe.addIngredient(ingredient, amount = null, unit = null, ratio = null)
        }
    }

    @Test
    fun `addIngredient rejects non positive amount`() {
        val recipe = userRecipe()
        val ingredient = Ingredient(id = 1L, name = "참기름")

        assertThrows(IllegalArgumentException::class.java) {
            recipe.addIngredient(ingredient, amount = BigDecimal.ZERO, unit = "스푼", ratio = null)
        }
    }

    @Test
    fun `changeVisibility stores hidden state`() {
        val recipe = userRecipe()

        recipe.changeVisibility(RecipeVisibility.HIDDEN)

        assertEquals(RecipeVisibility.HIDDEN, recipe.visibility)
    }

    @Test
    fun `user recipe rejects author selected taste tag`() {
        val recipe = userRecipe()
        val tag = RecipeTag(id = 1L, name = "고소함")

        assertThrows(IllegalArgumentException::class.java) {
            recipe.addTag(tag)
        }
    }

    private fun userRecipe(): SauceRecipe {
        return SauceRecipe(
            title = "내 소스",
            description = "설명",
            spiceLevel = 0,
            richnessLevel = 0,
            authorType = RecipeAuthorType.USER,
            author = author
        )
    }
}
