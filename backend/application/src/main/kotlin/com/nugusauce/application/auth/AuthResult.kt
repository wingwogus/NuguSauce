package com.nugusauce.application.auth

import com.nugusauce.application.member.MemberResult

object AuthResult {
    enum class OnboardingStatus(val wireValue: String) {
        COMPLETE("complete"),
        REQUIRED("required")
    }

    enum class OnboardingRequiredAction(val wireValue: String) {
        ACCEPT_REQUIRED_POLICIES("accept_required_policies"),
        SETUP_PROFILE("setup_profile")
    }

    data class TokenPair(
        val accessToken: String,
        val refreshToken: String
    )

    data class Onboarding(
        val status: OnboardingStatus,
        val requiredActions: List<OnboardingRequiredAction>
    )

    data class SocialLogin(
        val accessToken: String,
        val refreshToken: String,
        val member: MemberResult.Me,
        val onboarding: Onboarding
    )
}
