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

    data class KakaoLoginResponse(
        val accessToken: String,
        val refreshToken: String,
        val member: MemberResponses.MeResponse
    ) {
        companion object {
            fun from(result: AuthResult.KakaoLogin): KakaoLoginResponse {
                return KakaoLoginResponse(
                    accessToken = result.accessToken,
                    refreshToken = result.refreshToken,
                    member = MemberResponses.MeResponse.from(result.member)
                )
            }
        }
    }
}
