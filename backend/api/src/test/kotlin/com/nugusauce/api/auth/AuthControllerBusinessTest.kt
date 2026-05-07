package com.nugusauce.api.auth

import com.nugusauce.api.exception.GlobalExceptionHandler
import com.nugusauce.application.auth.AuthCommand
import com.nugusauce.application.auth.AuthResult
import com.nugusauce.application.auth.AuthService
import com.nugusauce.application.auth.KakaoLoginService
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.member.MemberResult
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
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.header
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@WebMvcTest(AuthController::class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler::class)
class AuthControllerBusinessTest(
    @Autowired private val mockMvc: MockMvc
) {

    @MockBean
    private lateinit var authService: AuthService

    @MockBean
    private lateinit var kakaoLoginService: KakaoLoginService

    @MockBean
    private lateinit var tokenProvider: TokenProvider

    @Test
    fun `login returns token pair from service`() {
        `when`(authService.login(AuthCommand.Login("user@example.com", "password123")))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))

        mockMvc.perform(
            post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"email":"user@example.com","password":"password123"}""")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.success").value(true))
            .andExpect(jsonPath("$.data.accessToken", equalTo("access-token")))
            .andExpect(jsonPath("$.data.refreshToken", equalTo("refresh-token")))
    }

    @Test
    fun `send-code maps business exception to failure response`() {
        doThrow(object : BusinessException(ErrorCode.DUPLICATE_EMAIL) {})
            .`when`(authService)
            .sendVerificationCode(AuthCommand.SendVerificationCode("taken@example.com"))

        mockMvc.perform(
            post("/api/v1/auth/email/send-code")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"email":"taken@example.com"}""")
        )
            .andExpect(status().isConflict)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("AUTH_003")))
    }

    @Test
    fun `reissue returns rotated token pair and refresh cookie`() {
        `when`(authService.reissue(AuthCommand.Reissue("refresh-token")))
            .thenReturn(AuthResult.TokenPair("new-access-token", "new-refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        mockMvc.perform(
            post("/api/v1/auth/reissue")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"refreshToken":"refresh-token"}""")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.data.accessToken", equalTo("new-access-token")))
            .andExpect(jsonPath("$.data.refreshToken", equalTo("new-refresh-token")))
            .andExpect(header().string(HttpHeaders.SET_COOKIE, org.hamcrest.Matchers.containsString("refreshToken=new-refresh-token")))
    }

    @Test
    fun `kakao login returns token pair from service`() {
        `when`(kakaoLoginService.login(AuthCommand.KakaoLogin("id-token", "nonce", "kakao-access-token")))
            .thenReturn(
                AuthResult.KakaoLogin(
                    accessToken = "access-token",
                    refreshToken = "refresh-token",
                    member = MemberResult.Me(
                        id = 1L,
                        nickname = null,
                        displayName = "사용자 1",
                        profileImageUrl = null,
                        profileSetupRequired = true
                    ),
                    onboarding = AuthResult.Onboarding(
                        status = AuthResult.OnboardingStatus.REQUIRED,
                        requiredActions = listOf(AuthResult.OnboardingRequiredAction.SETUP_PROFILE)
                    )
                )
            )

        mockMvc.perform(
            post("/api/v1/auth/kakao/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"idToken":"id-token","nonce":"nonce","kakaoAccessToken":"kakao-access-token"}""")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.success").value(true))
            .andExpect(jsonPath("$.data.accessToken", equalTo("access-token")))
            .andExpect(jsonPath("$.data.refreshToken", equalTo("refresh-token")))
            .andExpect(jsonPath("$.data.member.id", equalTo(1)))
            .andExpect(jsonPath("$.data.member.displayName", equalTo("사용자 1")))
            .andExpect(jsonPath("$.data.member.profileSetupRequired", equalTo(true)))
            .andExpect(jsonPath("$.data.onboarding.status", equalTo("required")))
            .andExpect(jsonPath("$.data.onboarding.requiredActions[0]", equalTo("setup_profile")))
            .andExpect(jsonPath("$.data." + "next" + "Step").doesNotExist())
    }

    @Test
    fun `kakao login maps invalid token to unauthorized`() {
        doThrow(object : BusinessException(ErrorCode.INVALID_KAKAO_TOKEN) {})
            .`when`(kakaoLoginService)
            .login(AuthCommand.KakaoLogin("bad-token", "nonce", "bad-access-token"))

        mockMvc.perform(
            post("/api/v1/auth/kakao/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"idToken":"bad-token","nonce":"nonce","kakaoAccessToken":"bad-access-token"}""")
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code", equalTo("AUTH_009")))
    }
}
