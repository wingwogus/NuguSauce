package com.nugusauce.api.security

import com.nugusauce.application.security.TokenProvider
import org.hamcrest.Matchers.containsString
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.content
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@SpringBootTest(
    properties = [
        "spring.mail.username=test@example.com",
        "spring.mail.password=test-password"
    ]
)
@AutoConfigureMockMvc
@ActiveProfiles("local")
class AuthSecurityIntegrationTest(
    @Autowired private val mockMvc: MockMvc,
    @Autowired private val tokenProvider: TokenProvider
) {

    @Test
    fun `auth endpoints are publicly accessible`() {
        mockMvc.perform(
            post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"email":"invalid","password":"password123"}""")
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `kakao auth endpoint is publicly accessible`() {
        mockMvc.perform(
            post("/api/v1/auth/kakao/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"idToken":"","nonce":"nonce"}""")
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `oauth redirect routes are not public auth routes`() {
        mockMvc.perform(get("/oauth2/authorization/kakao"))
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `protected endpoint rejects missing token`() {
        mockMvc.perform(get("/api/v1/test/me"))
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `protected endpoint accepts valid jwt`() {
        val accessToken = tokenProvider.createAccessToken(42L, "ROLE_USER")

        mockMvc.perform(
            get("/api/v1/test/me")
                .header(HttpHeaders.AUTHORIZATION, "Bearer $accessToken")
        )
            .andExpect(status().isOk)
            .andExpect(content().string(containsString("42")))
    }

    @Test
    fun `refresh token cannot authenticate protected endpoint`() {
        val refreshToken = tokenProvider.createRefreshToken(42L)

        mockMvc.perform(
            get("/api/v1/test/me")
                .header(HttpHeaders.AUTHORIZATION, "Bearer $refreshToken")
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `logout requires authentication`() {
        mockMvc.perform(post("/api/v1/auth/logout"))
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `recipe public read endpoints are accessible without jwt`() {
        mockMvc.perform(get("/api/v1/home"))
            .andExpect(status().isOk)

        mockMvc.perform(get("/api/v1/recipes"))
            .andExpect(status().isOk)

        mockMvc.perform(get("/api/v1/recipes/999"))
            .andExpect(status().isNotFound)

        mockMvc.perform(get("/api/v1/recipes/999/reviews"))
            .andExpect(status().isNotFound)
    }

    @Test
    fun `recipe metadata endpoints are accessible without jwt`() {
        mockMvc.perform(get("/api/v1/ingredients"))
            .andExpect(status().isOk)

        mockMvc.perform(get("/api/v1/tags"))
            .andExpect(status().isOk)
    }

    @Test
    fun `recipe mutation endpoint rejects missing token`() {
        mockMvc.perform(
            post("/api/v1/recipes")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "title": "내 소스",
                      "description": "설명",
                      "ingredients": [
                        { "ingredientId": 1, "amount": 1.0, "unit": "스푼" }
                      ]
                    }
                    """.trimIndent()
                )
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `review and report mutation endpoints reject missing token`() {
        mockMvc.perform(
            post("/api/v1/recipes/1/reviews")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"rating":5,"text":"좋아요"}""")
        )
            .andExpect(status().isUnauthorized)

        mockMvc.perform(
            post("/api/v1/recipes/1/reports")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"reason":"부적절한 내용"}""")
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `my recipe endpoints require authentication`() {
        mockMvc.perform(get("/api/v1/me/recipes"))
            .andExpect(status().isUnauthorized)

        mockMvc.perform(get("/api/v1/me/favorite-recipes"))
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `member self endpoint requires authentication but public member profile is readable`() {
        mockMvc.perform(get("/api/v1/members/me"))
            .andExpect(status().isUnauthorized)

        mockMvc.perform(get("/api/v1/members/999"))
            .andExpect(status().isNotFound)
    }

    @Test
    fun `favorite mutation endpoints require authentication`() {
        mockMvc.perform(post("/api/v1/me/favorite-recipes/1"))
            .andExpect(status().isUnauthorized)

        mockMvc.perform(delete("/api/v1/me/favorite-recipes/1"))
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `my recipe mutation endpoints require authentication`() {
        mockMvc.perform(
            patch("/api/v1/me/recipes/1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "title": "내 소스",
                      "description": "설명",
                      "ingredients": [
                        { "ingredientId": 1, "amount": 1.0, "unit": "스푼" }
                      ]
                    }
                    """.trimIndent()
                )
        )
            .andExpect(status().isUnauthorized)

        mockMvc.perform(delete("/api/v1/me/recipes/1"))
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `admin recipe visibility endpoint rejects user role`() {
        val accessToken = tokenProvider.createAccessToken(42L, "ROLE_USER")

        mockMvc.perform(
            patch("/api/v1/admin/recipes/1/visibility")
                .header(HttpHeaders.AUTHORIZATION, "Bearer $accessToken")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"visibility":"HIDDEN"}""")
        )
            .andExpect(status().isForbidden)
    }

    @Test
    fun `admin recipe visibility endpoint accepts admin role before business handling`() {
        val accessToken = tokenProvider.createAccessToken(99L, "ROLE_ADMIN")

        mockMvc.perform(
            patch("/api/v1/admin/recipes/999/visibility")
                .header(HttpHeaders.AUTHORIZATION, "Bearer $accessToken")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"visibility":"HIDDEN"}""")
        )
            .andExpect(status().isNotFound)
    }
}
