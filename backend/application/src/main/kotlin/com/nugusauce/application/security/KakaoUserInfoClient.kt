package com.nugusauce.application.security

interface KakaoUserInfoClient {
    fun fetch(accessToken: String): KakaoUserInfo
}

data class KakaoUserInfo(
    val subject: String,
    val email: String?,
    val emailVerified: Boolean
)
