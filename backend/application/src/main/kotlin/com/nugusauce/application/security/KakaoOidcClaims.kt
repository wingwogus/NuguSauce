package com.nugusauce.application.security

import java.time.Instant

data class KakaoOidcClaims(
    val subject: String,
    val email: String?,
    val emailVerified: Boolean,
    val nonce: String,
    val expiresAt: Instant
)
