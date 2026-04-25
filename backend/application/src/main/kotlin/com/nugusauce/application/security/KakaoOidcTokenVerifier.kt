package com.nugusauce.application.security

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nimbusds.jose.util.DefaultResourceRetriever
import com.nimbusds.jose.util.JSONObjectUtils
import com.nimbusds.jwt.JWTParser
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.beans.factory.annotation.Value
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.security.oauth2.jwt.JwtDecoder
import org.springframework.security.oauth2.jwt.JwtException
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder
import org.springframework.stereotype.Service
import java.net.URI
import java.text.ParseException
import java.time.Duration
import java.time.Instant

@Service
class KakaoOidcTokenVerifier private constructor(
    private val issuer: String,
    private val audience: String,
    private val allowedClockSkew: Duration,
    jwtDecoderProvider: () -> JwtDecoder
) {
    private val jwtDecoder: JwtDecoder by lazy(jwtDecoderProvider)

    @Autowired
    constructor(
        @Value("\${auth.kakao.oidc.issuer:https://kauth.kakao.com}")
        issuer: String,
        @Value("\${auth.kakao.oidc.audience}")
        audience: String,
        @Value("\${auth.kakao.oidc.discovery-uri:https://kauth.kakao.com/.well-known/openid-configuration}")
        discoveryUri: String,
        @Value("\${auth.kakao.oidc.allowed-clock-skew-seconds:60}")
        allowedClockSkewSeconds: Long
    ) : this(
        issuer = issuer,
        audience = audience,
        allowedClockSkew = Duration.ofSeconds(allowedClockSkewSeconds),
        jwtDecoderProvider = {
            buildDecoderFromDiscovery(discoveryUri)
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

    fun verify(idToken: String, expectedNonce: String): KakaoOidcClaims {
        parseJwtShape(idToken)

        val jwt = try {
            jwtDecoder.decode(idToken)
        } catch (exception: JwtException) {
            throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)
        } catch (exception: Exception) {
            throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)
        }

        validateIssuer(jwt)
        validateAudience(jwt)
        validateTimestamps(jwt)

        val actualNonce = jwt.getClaimAsString(NONCE_CLAIM)
            ?: throw BusinessException(ErrorCode.KAKAO_NONCE_MISMATCH)
        if (actualNonce != expectedNonce) {
            throw BusinessException(ErrorCode.KAKAO_NONCE_MISMATCH)
        }

        val subject = jwt.subject?.takeIf { it.isNotBlank() }
            ?: throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)
        val expiresAt = jwt.expiresAt
            ?: throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)

        return KakaoOidcClaims(
            subject = subject,
            email = jwt.getClaimAsString(EMAIL_CLAIM),
            emailVerified = jwt.getClaim<Boolean>(EMAIL_VERIFIED_CLAIM) == true,
            nonce = actualNonce,
            expiresAt = expiresAt
        )
    }

    private fun validateIssuer(jwt: Jwt) {
        if (jwt.issuer?.toString() != issuer) {
            throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)
        }
    }

    private fun validateAudience(jwt: Jwt) {
        if (!jwt.audience.contains(audience)) {
            throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)
        }
    }

    private fun validateTimestamps(jwt: Jwt) {
        val now = Instant.now()
        val expiresAt = jwt.expiresAt ?: throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)
        if (expiresAt.plus(allowedClockSkew).isBefore(now)) {
            throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)
        }

        val issuedAt = jwt.issuedAt ?: throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)
        if (issuedAt.minus(allowedClockSkew).isAfter(now)) {
            throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)
        }
    }

    private fun parseJwtShape(idToken: String) {
        try {
            JWTParser.parse(idToken)
        } catch (exception: ParseException) {
            throw BusinessException(ErrorCode.MALFORMED_JWT)
        }
    }

    companion object {
        private const val NONCE_CLAIM = "nonce"
        private const val EMAIL_CLAIM = "email"
        private const val EMAIL_VERIFIED_CLAIM = "email_verified"
        private const val JWKS_URI_FIELD = "jwks_uri"

        private fun buildDecoderFromDiscovery(discoveryUri: String): JwtDecoder {
            val retriever = DefaultResourceRetriever(2_000, 2_000)
            val resource = retriever.retrieveResource(URI.create(discoveryUri).toURL())
            val metadata = JSONObjectUtils.parse(resource.content)
            val jwksUri = JSONObjectUtils.getURI(metadata, JWKS_URI_FIELD)
                ?: URI.create("https://kauth.kakao.com/.well-known/jwks.json")

            return NimbusJwtDecoder.withJwkSetUri(jwksUri.toString()).build()
        }
    }
}
