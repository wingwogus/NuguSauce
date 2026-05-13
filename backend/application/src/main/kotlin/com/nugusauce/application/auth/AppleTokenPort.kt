package com.nugusauce.application.auth

interface AppleTokenPort {
    fun exchangeAuthorizationCode(authorizationCode: String): AppleTokenResult?
    fun revokeRefreshToken(refreshToken: String)
}

data class AppleTokenResult(
    val refreshToken: String?
)
