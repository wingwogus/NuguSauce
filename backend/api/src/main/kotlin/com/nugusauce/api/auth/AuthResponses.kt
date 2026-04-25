package com.nugusauce.api.auth

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
}
