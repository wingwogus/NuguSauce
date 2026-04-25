package com.nugusauce.application.security

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class TokenProviderTest {

    private val tokenProvider = TokenProvider(
        "t2oRk29vBQZWS8GEt4xr8AJznlPK0ipBKUwdyqe10SOGZB26vVBMjzqualdJsjcOY1wX9DOqJC9V1DFl58F0tQ=="
    )

    @Test
    fun `generateToken embeds user id and role in access token`() {
        val tokenPair = tokenProvider.generateToken(7L, "ROLE_USER")

        assertTrue(tokenProvider.validateToken(tokenPair.accessToken))
        assertTrue(tokenProvider.isAccessToken(tokenPair.accessToken))
        assertEquals(7L, tokenProvider.getUserId(tokenPair.accessToken))
        assertEquals("ROLE_USER", tokenProvider.getRole(tokenPair.accessToken))
    }

    @Test
    fun `refresh token is bound to the user id`() {
        val refreshToken = tokenProvider.createRefreshToken(9L)
        val authentication = tokenProvider.getAuthentication(
            tokenProvider.createAccessToken(9L, "ROLE_ADMIN")
        )

        assertTrue(tokenProvider.validateToken(refreshToken))
        assertTrue(tokenProvider.isRefreshToken(refreshToken))
        assertEquals(9L, tokenProvider.getUserId(refreshToken))
        assertEquals("9", authentication.principal)
        assertEquals("ROLE_ADMIN", authentication.authorities.first().authority)
    }
}
