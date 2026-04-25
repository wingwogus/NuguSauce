package com.nugusauce.application.auth

object AuthCommand {
    data class SendVerificationCode(
        val email: String
    )

    data class VerifyEmailCode(
        val email: String,
        val code: String
    )

    data class SignUp(
        val email: String,
        val password: String
    )

    data class Login(
        val email: String,
        val password: String
    )

    data class KakaoLogin(
        val idToken: String,
        val nonce: String
    )

    data class Reissue(
        val refreshToken: String
    )
}
