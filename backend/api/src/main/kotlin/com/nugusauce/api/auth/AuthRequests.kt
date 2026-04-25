package com.nugusauce.api.auth

import jakarta.validation.constraints.Email
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size

object AuthRequests {
    data class SendVerificationCodeRequest(
        @field:NotBlank(message = "이메일을 입력해주세요")
        @field:Email(message = "이메일 형식이 올바르지 않습니다")
        val email: String
    )

    data class VerifyEmailCodeRequest(
        @field:NotBlank(message = "이메일을 입력해주세요")
        @field:Email(message = "이메일 형식이 올바르지 않습니다")
        val email: String,
        @field:NotBlank(message = "인증번호를 입력해주세요")
        @field:Size(min = 6, max = 6, message = "인증번호는 6자리여야 합니다")
        val code: String
    )

    data class SignUpRequest(
        @field:NotBlank(message = "이메일을 입력해주세요")
        @field:Email(message = "이메일 형식이 올바르지 않습니다")
        val email: String,
        @field:NotBlank(message = "비밀번호를 입력해주세요")
        @field:Size(min = 8, message = "비밀번호는 8자 이상이어야 합니다")
        val password: String
    )

    data class LoginRequest(
        @field:NotBlank(message = "이메일을 입력해주세요")
        @field:Email(message = "이메일 형식이 올바르지 않습니다")
        val email: String,
        @field:NotBlank(message = "비밀번호를 입력해주세요")
        val password: String
    )

    data class KakaoLoginRequest(
        @field:NotBlank(message = "카카오 ID 토큰을 입력해주세요")
        val idToken: String,
        @field:NotBlank(message = "nonce를 입력해주세요")
        val nonce: String,
        @field:NotBlank(message = "카카오 액세스 토큰을 입력해주세요")
        val kakaoAccessToken: String? = null
    )

    data class ReissueRequest(
        val refreshToken: String? = null
    )
}
