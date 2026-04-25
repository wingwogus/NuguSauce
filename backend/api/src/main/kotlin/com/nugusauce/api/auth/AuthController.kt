package com.nugusauce.api.auth

import com.nugusauce.api.common.ApiResponse
import com.nugusauce.application.auth.AuthCommand
import com.nugusauce.application.auth.AuthService
import com.nugusauce.application.auth.KakaoLoginService
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.security.TokenProvider
import jakarta.validation.Valid
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseCookie
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.CookieValue
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/auth")
class AuthController(
    private val authService: AuthService,
    private val kakaoLoginService: KakaoLoginService,
    private val tokenProvider: TokenProvider
) {

    @PostMapping("/email/send-code")
    fun sendVerificationCode(
        @Valid @RequestBody request: AuthRequests.SendVerificationCodeRequest
    ): ResponseEntity<ApiResponse<Unit>> {
        authService.sendVerificationCode(AuthCommand.SendVerificationCode(request.email))
        return ResponseEntity.ok(ApiResponse.empty(Unit))
    }

    @PostMapping("/email/verify-code")
    fun verifyEmailCode(
        @Valid @RequestBody request: AuthRequests.VerifyEmailCodeRequest
    ): ResponseEntity<ApiResponse<Unit>> {
        authService.verifyEmailCode(AuthCommand.VerifyEmailCode(request.email, request.code))
        return ResponseEntity.ok(ApiResponse.empty(Unit))
    }

    @PostMapping("/signup")
    fun signUp(
        @Valid @RequestBody request: AuthRequests.SignUpRequest
    ): ResponseEntity<ApiResponse<Unit>> {
        authService.signUp(AuthCommand.SignUp(request.email, request.password))
        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.empty(Unit))
    }

    @PostMapping("/login")
    fun login(
        @Valid @RequestBody request: AuthRequests.LoginRequest
    ): ResponseEntity<ApiResponse<AuthResponses.TokenResponse>> {
        val result = authService.login(AuthCommand.Login(request.email, request.password))
        return ResponseEntity.ok(ApiResponse.ok(AuthResponses.TokenResponse.from(result)))
    }

    @PostMapping("/kakao/login")
    fun kakaoLogin(
        @Valid @RequestBody request: AuthRequests.KakaoLoginRequest
    ): ResponseEntity<ApiResponse<AuthResponses.TokenResponse>> {
        val result = kakaoLoginService.login(AuthCommand.KakaoLogin(request.idToken, request.nonce))
        return ResponseEntity.ok(ApiResponse.ok(AuthResponses.TokenResponse.from(result)))
    }

    @PostMapping("/reissue")
    fun reissue(
        @RequestBody(required = false) request: AuthRequests.ReissueRequest?,
        @CookieValue(name = "refreshToken", required = false) refreshTokenCookie: String?
    ): ResponseEntity<ApiResponse<AuthResponses.TokenResponse>> {
        val refreshToken = request?.refreshToken ?: refreshTokenCookie
            ?: throw BusinessException(ErrorCode.UNAUTHORIZED)
        val result = authService.reissue(AuthCommand.Reissue(refreshToken))
        return ResponseEntity.ok()
            .header(HttpHeaders.SET_COOKIE, refreshTokenCookie(result.refreshToken).toString())
            .body(ApiResponse.ok(AuthResponses.TokenResponse.from(result)))
    }

    @PostMapping("/logout")
    fun logout(
        @AuthenticationPrincipal userId: String
    ): ResponseEntity<ApiResponse<Unit>> {
        authService.logout(userId)
        return ResponseEntity.ok()
            .header(HttpHeaders.SET_COOKIE, clearRefreshTokenCookie().toString())
            .body(ApiResponse.empty(Unit))
    }

    private fun refreshTokenCookie(refreshToken: String): ResponseCookie {
        return ResponseCookie.from("refreshToken", refreshToken)
            .httpOnly(true)
            .secure(false)
            .path("/")
            .sameSite("Lax")
            .maxAge(tokenProvider.getRefreshTokenValiditySeconds())
            .build()
    }

    private fun clearRefreshTokenCookie(): ResponseCookie {
        return ResponseCookie.from("refreshToken", "")
            .httpOnly(true)
            .secure(false)
            .path("/")
            .sameSite("Lax")
            .maxAge(0)
            .build()
    }
}
