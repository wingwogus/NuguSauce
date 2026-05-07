package com.nugusauce.application.auth

import com.nugusauce.application.member.MemberResult

object AuthResult {
    enum class LoginNextStep(val wireValue: String) {
        DONE("done"),
        CONSENT_REQUIRED("consent_required"),
        PROFILE_REQUIRED("profile_required")
    }

    data class TokenPair(
        val accessToken: String,
        val refreshToken: String
    )

    data class KakaoLogin(
        val accessToken: String,
        val refreshToken: String,
        val member: MemberResult.Me,
        val nextStep: LoginNextStep
    )
}
