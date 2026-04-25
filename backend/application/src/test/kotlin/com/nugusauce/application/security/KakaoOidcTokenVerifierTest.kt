package com.nugusauce.application.security

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nimbusds.jose.JWSAlgorithm
import com.nimbusds.jose.JWSHeader
import com.nimbusds.jose.crypto.RSASSASigner
import com.nimbusds.jwt.JWTClaimsSet
import com.nimbusds.jwt.SignedJWT
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.interfaces.RSAPrivateKey
import java.security.interfaces.RSAPublicKey
import java.time.Duration
import java.time.Instant
import java.util.Date

class KakaoOidcTokenVerifierTest {

    private val keyPair = rsaKeyPair()
    private val verifier = verifierFor(keyPair)

    @Test
    fun `verify accepts valid kakao oidc token`() {
        val claims = verifier.verify(token(), NONCE)

        assertEquals("kakao-sub", claims.subject)
        assertEquals("user@example.com", claims.email)
        assertEquals(true, claims.emailVerified)
        assertEquals(NONCE, claims.nonce)
    }

    @Test
    fun `verify rejects malformed jwt`() {
        val exception = assertThrows(BusinessException::class.java) {
            verifier.verify("not-a-jwt", NONCE)
        }

        assertEquals(ErrorCode.MALFORMED_JWT, exception.errorCode)
    }

    @Test
    fun `verify rejects wrong issuer`() {
        val exception = assertThrows(BusinessException::class.java) {
            verifier.verify(token(issuer = "https://wrong.example.com"), NONCE)
        }

        assertEquals(ErrorCode.INVALID_KAKAO_TOKEN, exception.errorCode)
    }

    @Test
    fun `verify rejects wrong audience`() {
        val exception = assertThrows(BusinessException::class.java) {
            verifier.verify(token(audience = "wrong-audience"), NONCE)
        }

        assertEquals(ErrorCode.INVALID_KAKAO_TOKEN, exception.errorCode)
    }

    @Test
    fun `verify rejects expired token`() {
        val exception = assertThrows(BusinessException::class.java) {
            verifier.verify(
                token(
                    expiresAt = Instant.now().minusSeconds(120),
                    issuedAt = Instant.now().minusSeconds(240)
                ),
                NONCE
            )
        }

        assertEquals(ErrorCode.INVALID_KAKAO_TOKEN, exception.errorCode)
    }

    @Test
    fun `verify rejects bad signature`() {
        val otherKeyPair = rsaKeyPair()
        val exception = assertThrows(BusinessException::class.java) {
            verifier.verify(token(signingKeyPair = otherKeyPair), NONCE)
        }

        assertEquals(ErrorCode.INVALID_KAKAO_TOKEN, exception.errorCode)
    }

    @Test
    fun `verify rejects nonce mismatch`() {
        val exception = assertThrows(BusinessException::class.java) {
            verifier.verify(token(nonce = "token-nonce"), NONCE)
        }

        assertEquals(ErrorCode.KAKAO_NONCE_MISMATCH, exception.errorCode)
    }

    private fun verifierFor(keyPair: KeyPair): KakaoOidcTokenVerifier {
        val decoder = NimbusJwtDecoder
            .withPublicKey(keyPair.public as RSAPublicKey)
            .build()
        decoder.setJwtValidator { OAuth2TokenValidatorResult.success() }

        return KakaoOidcTokenVerifier(
            issuer = ISSUER,
            audience = AUDIENCE,
            allowedClockSkew = Duration.ofSeconds(30),
            jwtDecoder = decoder
        )
    }

    private fun token(
        signingKeyPair: KeyPair = keyPair,
        issuer: String = ISSUER,
        audience: String = AUDIENCE,
        subject: String = "kakao-sub",
        email: String? = "user@example.com",
        emailVerified: Boolean? = true,
        nonce: String = NONCE,
        expiresAt: Instant = Instant.now().plusSeconds(300),
        issuedAt: Instant = Instant.now().minusSeconds(10)
    ): String {
        val claims = JWTClaimsSet.Builder()
            .issuer(issuer)
            .audience(audience)
            .subject(subject)
            .expirationTime(Date.from(expiresAt))
            .issueTime(Date.from(issuedAt))
            .claim("nonce", nonce)
            .apply {
                if (email != null) {
                    claim("email", email)
                }
                if (emailVerified != null) {
                    claim("email_verified", emailVerified)
                }
            }
            .build()

        val signedJwt = SignedJWT(JWSHeader(JWSAlgorithm.RS256), claims)
        signedJwt.sign(RSASSASigner(signingKeyPair.private as RSAPrivateKey))
        return signedJwt.serialize()
    }

    private fun rsaKeyPair(): KeyPair {
        return KeyPairGenerator.getInstance("RSA")
            .apply { initialize(2048) }
            .generateKeyPair()
    }

    companion object {
        private const val ISSUER = "https://kauth.kakao.com"
        private const val AUDIENCE = "test-kakao-native-app-key"
        private const val NONCE = "client-nonce"
    }
}
