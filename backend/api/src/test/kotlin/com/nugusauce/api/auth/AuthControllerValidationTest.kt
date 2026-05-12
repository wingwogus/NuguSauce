package com.nugusauce.api.auth

import com.nugusauce.api.exception.GlobalExceptionHandler
import com.nugusauce.application.auth.AppleLoginService
import com.nugusauce.application.auth.AuthService
import com.nugusauce.application.auth.KakaoLoginService
import com.nugusauce.application.security.TokenProvider
import org.hamcrest.Matchers.equalTo
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest
import org.springframework.boot.test.mock.mockito.MockBean
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@WebMvcTest(AuthController::class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler::class)
class AuthControllerValidationTest(
    @Autowired private val mockMvc: MockMvc
) {

    @MockBean
    private lateinit var authService: AuthService

    @MockBean
    private lateinit var kakaoLoginService: KakaoLoginService

    @MockBean
    private lateinit var appleLoginService: AppleLoginService

    @MockBean
    private lateinit var tokenProvider: TokenProvider

    @Test
    fun `send-code rejects invalid email`() {
        mockMvc.perform(
            post("/api/v1/auth/email/send-code")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"email":"not-an-email"}""")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("COMMON_001")))
    }

    @Test
    fun `signup rejects short password`() {
        mockMvc.perform(
            post("/api/v1/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"email":"user@example.com","password":"123"}""")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("COMMON_001")))
    }

    @Test
    fun `kakao login rejects missing id token`() {
        mockMvc.perform(
            post("/api/v1/auth/kakao/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"idToken":"","nonce":"nonce","kakaoAccessToken":"kakao-access-token"}""")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("COMMON_001")))
    }

    @Test
    fun `kakao login rejects missing kakao access token`() {
        mockMvc.perform(
            post("/api/v1/auth/kakao/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"idToken":"id-token","nonce":"nonce","kakaoAccessToken":""}""")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("COMMON_001")))
    }

    @Test
    fun `apple login rejects missing identity token`() {
        mockMvc.perform(
            post("/api/v1/auth/apple/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"identityToken":"","nonce":"raw-nonce"}""")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("COMMON_001")))
    }

    @Test
    fun `apple login rejects missing nonce`() {
        mockMvc.perform(
            post("/api/v1/auth/apple/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"identityToken":"identity-token","nonce":""}""")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("COMMON_001")))
    }
}
