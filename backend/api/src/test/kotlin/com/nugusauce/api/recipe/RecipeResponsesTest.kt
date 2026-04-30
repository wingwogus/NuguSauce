package com.nugusauce.api.recipe

import com.nugusauce.application.recipe.RecipeResult
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import java.time.Instant

class RecipeResponsesTest {
    @Test
    fun `recipe summary response exposes favorite state`() {
        val response = RecipeResponses.RecipeSummaryResponse.from(
            RecipeResult.RecipeSummary(
                id = 101L,
                title = "마늘 듬뿍 고소 소스",
                description = "마늘 향이 강한 조합",
                spiceLevel = 0,
                richnessLevel = 0,
                imageUrl = null,
                authorType = "USER",
                visibility = "VISIBLE",
                ratingSummary = RecipeResult.RatingSummary(4.7, 18),
                tags = emptyList(),
                reviewTags = emptyList(),
                isFavorite = true,
                createdAt = Instant.parse("2026-04-25T00:00:00Z")
            )
        )

        assertEquals(true, response.isFavorite)
    }

    @Test
    fun `recipe detail response exposes author name`() {
        val response = RecipeResponses.RecipeDetailResponse.from(
            RecipeResult.RecipeDetail(
                id = 101L,
                title = "마늘 듬뿍 고소 소스",
                description = "마늘 향이 강한 조합",
                spiceLevel = 0,
                richnessLevel = 0,
                imageUrl = null,
                tips = null,
                authorType = "USER",
                authorId = 7L,
                authorName = "소스장인",
                visibility = "VISIBLE",
                ingredients = emptyList(),
                tags = emptyList(),
                reviewTags = emptyList(),
                ratingSummary = RecipeResult.RatingSummary(0.0, 0),
                isFavorite = true,
                createdAt = Instant.parse("2026-04-25T00:00:00Z"),
                lastReviewedAt = null
            )
        )

        assertEquals(7L, response.authorId)
        assertEquals("소스장인", response.authorName)
        assertEquals(true, response.isFavorite)
    }

    @Test
    fun `curated recipe detail response supports missing author id`() {
        val response = RecipeResponses.RecipeDetailResponse.from(
            RecipeResult.RecipeDetail(
                id = 102L,
                title = "건희 소스",
                description = "유명 조합",
                spiceLevel = 0,
                richnessLevel = 0,
                imageUrl = null,
                tips = null,
                authorType = "CURATED",
                authorId = null,
                authorName = "NuguSauce",
                visibility = "VISIBLE",
                ingredients = emptyList(),
                tags = emptyList(),
                reviewTags = emptyList(),
                ratingSummary = RecipeResult.RatingSummary(0.0, 0),
                isFavorite = false,
                createdAt = Instant.parse("2026-04-25T00:00:00Z"),
                lastReviewedAt = null
            )
        )

        assertEquals(null, response.authorId)
        assertEquals("NuguSauce", response.authorName)
    }

    @Test
    fun `review response exposes author name`() {
        val response = RecipeResponses.ReviewResponse.from(
            RecipeResult.ReviewItem(
                id = 10L,
                recipeId = 1L,
                authorId = 8L,
                authorName = "리뷰장인",
                rating = 5,
                text = "고소하고 좋아요",
                tasteTags = emptyList(),
                createdAt = Instant.parse("2026-04-25T01:00:00Z")
            )
        )

        assertEquals(8L, response.authorId)
        assertEquals("리뷰장인", response.authorName)
    }
}
