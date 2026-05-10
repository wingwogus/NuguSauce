package com.nugusauce.api.recipe

import com.nugusauce.api.exception.GlobalExceptionHandler
import com.nugusauce.application.consent.ConsentService
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.recipe.RecipeCommand
import com.nugusauce.application.recipe.RecipeFavoriteService
import com.nugusauce.application.recipe.RecipeModerationService
import com.nugusauce.application.recipe.RecipeQueryService
import com.nugusauce.application.recipe.RecipeReviewService
import com.nugusauce.application.recipe.RecipeResult
import com.nugusauce.application.recipe.RecipeWriteService
import com.nugusauce.application.security.TokenProvider
import org.hamcrest.Matchers.equalTo
import org.junit.jupiter.api.Test
import org.mockito.Mockito.doThrow
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
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch
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
    private lateinit var consentService: ConsentService

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
    fun `search accepts hot sort`() {
        `when`(recipeQueryService.search(RecipeCommand.SearchRecipes(sort = RecipeCommand.RecipeSort.HOT)))
            .thenReturn(emptyList())

        mockMvc.perform(get("/api/v1/recipes?sort=hot"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.success").value(true))
    }

    @Test
    fun `search includes favorite state for authenticated principal`() {
        `when`(recipeQueryService.search(RecipeCommand.SearchRecipes(viewerMemberId = 1L)))
            .thenReturn(listOf(recipeSummary(isFavorite = true)))

        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken("1", null)
        try {
            mockMvc.perform(get("/api/v1/recipes"))
                .andExpect(status().isOk)
                .andExpect(jsonPath("$.data[0].isFavorite").value(true))
        } finally {
            SecurityContextHolder.clearContext()
        }
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
    fun `create rejects direct image url`() {
        mockMvc.perform(
            post("/api/v1/recipes")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "title": "내 소스",
                      "description": "설명",
                      "imageUrl": "https://example.test/image.jpg",
                      "ingredients": [
                        { "ingredientId": 1, "amount": 1.0, "unit": "스푼" }
                      ]
                    }
                    """.trimIndent()
                )
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("COMMON_001")))
            .andExpect(jsonPath("$.error.detail.field", equalTo("imageUrl")))
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

    @Test
    fun `create maps missing consent to stable error`() {
        doThrow(consentRequired()).`when`(consentService).requireRequiredConsents(1L)
        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken("1", null)
        try {
            mockMvc.perform(
                post("/api/v1/recipes")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(validCreateRecipeBody())
            )
                .andExpect(status().`is`(428))
                .andExpect(jsonPath("$.error.code", equalTo("CONSENT_001")))
        } finally {
            SecurityContextHolder.clearContext()
        }
    }

    @Test
    fun `update returns updated recipe detail`() {
        `when`(
            recipeWriteService.update(
                RecipeCommand.UpdateRecipe(
                    authorId = 1L,
                    recipeId = 10L,
                    title = "내 소스 수정",
                    description = "설명 수정",
                    imageId = 20L,
                    tips = "잘 섞기",
                    ingredients = listOf(
                        RecipeCommand.IngredientInput(
                            ingredientId = 1L,
                            amount = java.math.BigDecimal("1.0"),
                            unit = "스푼"
                        )
                    )
                )
            )
        ).thenReturn(recipeDetail(isFavorite = false).copy(title = "내 소스 수정", description = "설명 수정"))
        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken("1", null)
        try {
            mockMvc.perform(
                patch("/api/v1/me/recipes/10")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(validUpdateRecipeBody())
            )
                .andExpect(status().isOk)
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.title", equalTo("내 소스 수정")))
        } finally {
            SecurityContextHolder.clearContext()
        }
    }

    @Test
    fun `update rejects direct image url`() {
        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken("1", null)
        try {
            mockMvc.perform(
                patch("/api/v1/me/recipes/10")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(updateRecipeBodyWithForbiddenFields())
            )
                .andExpect(status().isBadRequest)
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code", equalTo("COMMON_001")))
        } finally {
            SecurityContextHolder.clearContext()
        }
    }

    @Test
    fun `update rejects anonymous before deprecated image url semantics`() {
        mockMvc.perform(
            patch("/api/v1/me/recipes/10")
                .contentType(MediaType.APPLICATION_JSON)
                .content(updateRecipeBodyWithForbiddenFields())
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("AUTH_001")))
    }

    @Test
    fun `update maps missing consent to stable error`() {
        doThrow(consentRequired()).`when`(consentService).requireRequiredConsents(1L)
        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken("1", null)
        try {
            mockMvc.perform(
                patch("/api/v1/me/recipes/10")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(validUpdateRecipeBody())
            )
                .andExpect(status().`is`(428))
                .andExpect(jsonPath("$.error.code", equalTo("CONSENT_001")))
        } finally {
            SecurityContextHolder.clearContext()
        }
    }

    @Test
    fun `delete returns empty success envelope`() {
        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken("1", null)
        try {
            mockMvc.perform(delete("/api/v1/me/recipes/10"))
                .andExpect(status().isOk)
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data").doesNotExist())
        } finally {
            SecurityContextHolder.clearContext()
        }
    }

    @Test
    fun `delete maps missing consent to stable error`() {
        doThrow(consentRequired()).`when`(consentService).requireRequiredConsents(1L)
        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken("1", null)
        try {
            mockMvc.perform(delete("/api/v1/me/recipes/10"))
                .andExpect(status().`is`(428))
                .andExpect(jsonPath("$.error.code", equalTo("CONSENT_001")))
        } finally {
            SecurityContextHolder.clearContext()
        }
    }

    @Test
    fun `review maps missing consent to stable error`() {
        doThrow(consentRequired()).`when`(consentService).requireRequiredConsents(1L)
        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken("1", null)
        try {
            mockMvc.perform(
                post("/api/v1/recipes/10/reviews")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("""{"rating":5,"text":"고소하고 좋아요"}""")
            )
                .andExpect(status().`is`(428))
                .andExpect(jsonPath("$.error.code", equalTo("CONSENT_001")))
        } finally {
            SecurityContextHolder.clearContext()
        }
    }

    @Test
    fun `report maps missing consent to stable error`() {
        doThrow(consentRequired()).`when`(consentService).requireRequiredConsents(1L)
        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken("1", null)
        try {
            mockMvc.perform(
                post("/api/v1/recipes/10/reports")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("""{"reason":"부적절한 내용"}""")
            )
                .andExpect(status().`is`(428))
                .andExpect(jsonPath("$.error.code", equalTo("CONSENT_001")))
        } finally {
            SecurityContextHolder.clearContext()
        }
    }

    private fun consentRequired(): BusinessException =
        BusinessException(
            ErrorCode.CONSENT_REQUIRED,
            detail = mapOf("missingPolicies" to listOf(mapOf("policyType" to "terms_of_service")))
        )

    private fun validCreateRecipeBody(): String =
        """
        {
          "title": "내 소스",
          "description": "설명",
          "ingredients": [
            { "ingredientId": 1, "amount": 1.0, "unit": "스푼" }
          ]
        }
        """.trimIndent()

    private fun validUpdateRecipeBody(): String =
        """
        {
          "title": "내 소스 수정",
          "description": "설명 수정",
          "imageId": 20,
          "tips": "잘 섞기",
          "ingredients": [
            { "ingredientId": 1, "amount": 1.0, "unit": "스푼" }
          ]
        }
        """.trimIndent()

    private fun updateRecipeBodyWithForbiddenFields(): String =
        """
        {
          "title": "내 소스",
          "description": "설명",
          "imageUrl": "https://example.test/image.jpg",
          "ingredients": [
            { "ingredientId": 1, "amount": 1.0, "unit": "스푼" }
          ]
        }
        """.trimIndent()

    private fun recipeDetail(isFavorite: Boolean): RecipeResult.RecipeDetail {
        return RecipeResult.RecipeDetail(
            id = 10L,
            title = "건희 소스",
            description = "고소하고 매콤한 인기 조합",
            spiceLevel = 0,
            richnessLevel = 0,
            imageUrl = null,
            tips = null,
            authorId = null,
            authorName = "NuguSauce",
            authorProfileImageUrl = null,
            visibility = "VISIBLE",
            ingredients = emptyList(),
            tags = emptyList(),
            ratingSummary = RecipeResult.RatingSummary(0.0, 0),
            isFavorite = isFavorite,
            createdAt = Instant.parse("2026-04-25T00:00:00Z"),
            lastReviewedAt = null
        )
    }

    private fun recipeSummary(isFavorite: Boolean): RecipeResult.RecipeSummary {
        return RecipeResult.RecipeSummary(
            id = 10L,
            title = "건희 소스",
            description = "고소하고 매콤한 인기 조합",
            spiceLevel = 0,
            richnessLevel = 0,
            imageUrl = null,
            visibility = "VISIBLE",
            ratingSummary = RecipeResult.RatingSummary(4.7, 18),
            tags = emptyList(),
            isFavorite = isFavorite,
            createdAt = Instant.parse("2026-04-25T00:00:00Z")
        )
    }
}
