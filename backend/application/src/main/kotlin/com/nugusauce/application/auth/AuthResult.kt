package com.nugusauce.application.auth

import com.nugusauce.application.member.MemberResult

object AuthResult {
    data class TokenPair(
        val accessToken: String,
        val refreshToken: String
    )

    data class KakaoLogin(
        val accessToken: String,
        val refreshToken: String,
        val member: MemberResult.Me
    )
}
