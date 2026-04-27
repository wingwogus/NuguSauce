package com.nugusauce.api.recipe

import com.nugusauce.application.recipe.RecipeResult
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import java.time.Instant

class RecipeResponsesTest {
    @Test
    fun `review response exposes author name`() {
        val response = RecipeResponses.ReviewResponse.from(
            RecipeResult.ReviewItem(
                id = 10L,
                recipeId = 1L,
                authorName = "사용자 7",
                rating = 5,
                text = "고소하고 좋아요",
                tasteTags = emptyList(),
                createdAt = Instant.parse("2026-04-25T01:00:00Z")
            )
        )

        assertEquals("사용자 7", response.authorName)
    }
}
