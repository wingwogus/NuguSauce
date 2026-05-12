package com.nugusauce.api.auth

import com.nugusauce.api.member.MemberResponses
import com.nugusauce.application.auth.AuthResult

object AuthResponses {
    data class TokenResponse(
        val accessToken: String,
        val refreshToken: String
    ) {
        companion object {
            fun from(result: AuthResult.TokenPair): TokenResponse {
                return TokenResponse(
                    accessToken = result.accessToken,
                    refreshToken = result.refreshToken
                )
            }
        }
    }

    data class SocialLoginResponse(
        val accessToken: String,
        val refreshToken: String,
        val member: MemberResponses.MeResponse,
        val onboarding: OnboardingResponse
    ) {
        companion object {
            fun from(result: AuthResult.SocialLogin): SocialLoginResponse {
                return SocialLoginResponse(
                    accessToken = result.accessToken,
                    refreshToken = result.refreshToken,
                    member = MemberResponses.MeResponse.from(result.member),
                    onboarding = OnboardingResponse.from(result.onboarding)
                )
            }
        }
    }

    data class OnboardingResponse(
        val status: String,
        val requiredActions: List<String>
    ) {
        companion object {
            fun from(result: AuthResult.Onboarding): OnboardingResponse {
                return OnboardingResponse(
                    status = result.status.wireValue,
                    requiredActions = result.requiredActions.map { it.wireValue }
                )
            }
        }
    }
}
