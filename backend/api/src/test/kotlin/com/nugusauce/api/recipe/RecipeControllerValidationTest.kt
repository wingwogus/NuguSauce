package com.nugusauce.api.recipe

import com.nugusauce.api.exception.GlobalExceptionHandler
import com.nugusauce.application.recipe.RecipeFavoriteService
import com.nugusauce.application.recipe.RecipeModerationService
import com.nugusauce.application.recipe.RecipeQueryService
import com.nugusauce.application.recipe.RecipeReviewService
import com.nugusauce.application.recipe.RecipeResult
import com.nugusauce.application.recipe.RecipeWriteService
import com.nugusauce.application.security.TokenProvider
import org.hamcrest.Matchers.equalTo
import org.junit.jupiter.api.Test
import org.mockito.Mockito.`when`
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest
import org.springframework.boot.test.mock.mockito.MockBean
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.Instant

@WebMvcTest(RecipeController::class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler::class)
class RecipeControllerValidationTest(
    @Autowired private val mockMvc: MockMvc
) {
    @MockBean
    private lateinit var recipeQueryService: RecipeQueryService

    @MockBean
    private lateinit var recipeWriteService: RecipeWriteService

    @MockBean
    private lateinit var recipeReviewService: RecipeReviewService

    @MockBean
    private lateinit var recipeModerationService: RecipeModerationService

    @MockBean
    private lateinit var recipeFavoriteService: RecipeFavoriteService

    @MockBean
    private lateinit var tokenProvider: TokenProvider

    @Test
    fun `search rejects unsupported sort`() {
        mockMvc.perform(get("/api/v1/recipes?sort=unknown"))
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("COMMON_001")))
    }

    @Test
    fun `detail includes favorite state for authenticated principal`() {
        `when`(recipeQueryService.getDetail(10L, 1L))
            .thenReturn(recipeDetail(isFavorite = true))

        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken("1", null)
        try {
            mockMvc.perform(get("/api/v1/recipes/10"))
                .andExpect(status().isOk)
                .andExpect(jsonPath("$.data.isFavorite").value(true))
        } finally {
            SecurityContextHolder.clearContext()
        }
    }

    @Test
    fun `create rejects empty ingredient list`() {
        mockMvc.perform(
            post("/api/v1/recipes")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "title": "내 소스",
                      "description": "설명",
                      "ingredients": []
                    }
                    """.trimIndent()
                )
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("COMMON_001")))
    }

    @Test
    fun `create rejects author selected taste classification`() {
        mockMvc.perform(
            post("/api/v1/recipes")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "title": "내 소스",
                      "description": "설명",
                      "spiceLevel": 2,
                      "richnessLevel": 4,
                      "ingredients": [
                        { "ingredientId": 1, "amount": 1.0, "unit": "스푼" }
                      ],
                      "tagIds": [1, 2]
                    }
                    """.trimIndent()
                )
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("COMMON_001")))
    }

    @Test
    fun `review rejects rating outside one to five`() {
        mockMvc.perform(
            post("/api/v1/recipes/1/reviews")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"rating":0,"text":"bad"}""")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("COMMON_001")))
    }

    private fun recipeDetail(isFavorite: Boolean): RecipeResult.RecipeDetail {
        return RecipeResult.RecipeDetail(
            id = 10L,
            title = "건희 소스",
            description = "고소하고 매콤한 인기 조합",
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
            isFavorite = isFavorite,
            createdAt = Instant.parse("2026-04-25T00:00:00Z"),
            lastReviewedAt = null
        )
    }
}
