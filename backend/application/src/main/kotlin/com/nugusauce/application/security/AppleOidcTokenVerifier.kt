package com.nugusauce.application.security

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nimbusds.jwt.JWTParser
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.beans.factory.annotation.Value
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.security.oauth2.jwt.JwtDecoder
import org.springframework.security.oauth2.jwt.JwtException
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder
import org.springframework.stereotype.Service
import java.security.MessageDigest
import java.text.ParseException
import java.time.Duration
import java.time.Instant

@Service
class AppleOidcTokenVerifier private constructor(
    private val issuer: String,
    private val audience: String,
    private val allowedClockSkew: Duration,
    jwtDecoderProvider: () -> JwtDecoder
) {
    private val jwtDecoder: JwtDecoder by lazy(jwtDecoderProvider)

    @Autowired
    constructor(
        @Value("\${auth.apple.oidc.issuer:https://appleid.apple.com}")
        issuer: String,
        @Value("\${auth.apple.oidc.audience}")
        audience: String,
        @Value("\${auth.apple.oidc.jwks-uri:https://appleid.apple.com/auth/keys}")
        jwksUri: String,
        @Value("\${auth.apple.oidc.allowed-clock-skew-seconds:60}")
        allowedClockSkewSeconds: Long
    ) : this(
        issuer = issuer,
        audience = audience,
        allowedClockSkew = Duration.ofSeconds(allowedClockSkewSeconds),
        jwtDecoderProvider = {
            NimbusJwtDecoder.withJwkSetUri(jwksUri).build()
        }
    )

    internal constructor(
        issuer: String,
        audience: String,
        allowedClockSkew: Duration,
        jwtDecoder: JwtDecoder
    ) : this(
        issuer = issuer,
        audience = audience,
        allowedClockSkew = allowedClockSkew,
        jwtDecoderProvider = { jwtDecoder }
    )

    fun verify(identityToken: String, rawNonce: String): AppleOidcClaims {
        parseJwtShape(identityToken)

        val jwt = try {
            jwtDecoder.decode(identityToken)
        } catch (exception: JwtException) {
            throw BusinessException(ErrorCode.INVALID_APPLE_TOKEN)
        } catch (exception: Exception) {
            throw BusinessException(ErrorCode.INVALID_APPLE_TOKEN)
        }

        validateIssuer(jwt)
        validateAudience(jwt)
        validateTimestamps(jwt)

        val expectedNonce = sha256Hex(rawNonce)
        val actualNonce = jwt.getClaimAsString(NONCE_CLAIM)
            ?: throw BusinessException(ErrorCode.APPLE_NONCE_MISMATCH)
        if (actualNonce != expectedNonce) {
            throw BusinessException(ErrorCode.APPLE_NONCE_MISMATCH)
        }

        val subject = jwt.subject?.takeIf { it.isNotBlank() }
            ?: throw BusinessException(ErrorCode.INVALID_APPLE_TOKEN)
        val expiresAt = jwt.expiresAt
            ?: throw BusinessException(ErrorCode.INVALID_APPLE_TOKEN)

        return AppleOidcClaims(
            subject = subject,
            email = jwt.getClaimAsString(EMAIL_CLAIM),
            emailVerified = emailVerified(jwt),
            nonce = actualNonce,
            expiresAt = expiresAt
        )
    }

    private fun validateIssuer(jwt: Jwt) {
        if (jwt.issuer?.toString() != issuer) {
            throw BusinessException(ErrorCode.INVALID_APPLE_TOKEN)
        }
    }

    private fun validateAudience(jwt: Jwt) {
        if (!jwt.audience.contains(audience)) {
            throw BusinessException(ErrorCode.INVALID_APPLE_TOKEN)
        }
    }

    private fun validateTimestamps(jwt: Jwt) {
        val now = Instant.now()
        val expiresAt = jwt.expiresAt ?: throw BusinessException(ErrorCode.INVALID_APPLE_TOKEN)
        if (expiresAt.plus(allowedClockSkew).isBefore(now)) {
            throw BusinessException(ErrorCode.INVALID_APPLE_TOKEN)
        }

        val issuedAt = jwt.issuedAt ?: throw BusinessException(ErrorCode.INVALID_APPLE_TOKEN)
        if (issuedAt.minus(allowedClockSkew).isAfter(now)) {
            throw BusinessException(ErrorCode.INVALID_APPLE_TOKEN)
        }
    }

    private fun emailVerified(jwt: Jwt): Boolean {
        return when (val value = jwt.claims[EMAIL_VERIFIED_CLAIM]) {
            is Boolean -> value
            is String -> value.equals("true", ignoreCase = true)
            else -> false
        }
    }

    private fun parseJwtShape(identityToken: String) {
        try {
            JWTParser.parse(identityToken)
        } catch (exception: ParseException) {
            throw BusinessException(ErrorCode.MALFORMED_JWT)
        }
    }

    private fun sha256Hex(value: String): String {
        return MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }

    companion object {
        private const val NONCE_CLAIM = "nonce"
        private const val EMAIL_CLAIM = "email"
        private const val EMAIL_VERIFIED_CLAIM = "email_verified"
    }
}
