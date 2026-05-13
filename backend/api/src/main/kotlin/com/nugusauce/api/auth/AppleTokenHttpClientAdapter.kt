package com.nugusauce.api.auth

import com.fasterxml.jackson.annotation.JsonProperty
import com.nugusauce.application.auth.AppleTokenPort
import com.nugusauce.application.auth.AppleTokenResult
import io.jsonwebtoken.Jwts
import io.jsonwebtoken.SignatureAlgorithm
import mu.KotlinLogging
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.MediaType
import org.springframework.stereotype.Component
import org.springframework.util.LinkedMultiValueMap
import org.springframework.web.client.RestClient
import org.springframework.web.client.RestClientException
import java.security.KeyFactory
import java.security.interfaces.ECPrivateKey
import java.security.spec.PKCS8EncodedKeySpec
import java.time.Instant
import java.util.Base64
import java.util.Date

@Component
class AppleTokenHttpClientAdapter(
    restClientBuilder: RestClient.Builder,
    @Value("\${auth.apple.oidc.audience:}") private val clientId: String,
    @Value("\${auth.apple.client.team-id:}") private val teamId: String,
    @Value("\${auth.apple.client.key-id:}") private val keyId: String,
    @Value("\${auth.apple.client.private-key:}") private val privateKeyPem: String,
    @Value("\${auth.apple.token-uri:https://appleid.apple.com/auth/token}") private val tokenUri: String,
    @Value("\${auth.apple.revoke-uri:https://appleid.apple.com/auth/revoke}") private val revokeUri: String
) : AppleTokenPort {
    private val restClient = restClientBuilder.build()

    override fun exchangeAuthorizationCode(authorizationCode: String): AppleTokenResult? {
        val clientSecret = clientSecretOrNull() ?: return null
        val form = LinkedMultiValueMap<String, String>().apply {
            add("client_id", clientId)
            add("client_secret", clientSecret)
            add("code", authorizationCode)
            add("grant_type", "authorization_code")
        }
        val response = try {
            restClient.post()
                .uri(tokenUri)
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .body(form)
                .retrieve()
                .body(AppleTokenResponse::class.java)
        } catch (e: RestClientException) {
            logger.warn(e) { "Apple authorization code exchange failed" }
            return null
        } ?: return null

        return AppleTokenResult(refreshToken = response.refreshToken)
    }

    override fun revokeRefreshToken(refreshToken: String) {
        val clientSecret = clientSecretOrNull() ?: return
        val form = LinkedMultiValueMap<String, String>().apply {
            add("client_id", clientId)
            add("client_secret", clientSecret)
            add("token", refreshToken)
            add("token_type_hint", "refresh_token")
        }
        restClient.post()
            .uri(revokeUri)
            .contentType(MediaType.APPLICATION_FORM_URLENCODED)
            .body(form)
            .retrieve()
            .toBodilessEntity()
    }

    private fun clientSecretOrNull(): String? {
        if (clientId.isBlank() || teamId.isBlank() || keyId.isBlank() || privateKeyPem.isBlank()) {
            logger.warn { "Apple token exchange/revocation skipped because client credentials are not configured" }
            return null
        }
        return Jwts.builder()
            .setHeaderParam("kid", keyId)
            .setIssuer(teamId)
            .setSubject(clientId)
            .setAudience("https://appleid.apple.com")
            .setIssuedAt(Date.from(Instant.now()))
            .setExpiration(Date.from(Instant.now().plusSeconds(CLIENT_SECRET_TTL_SECONDS)))
            .signWith(parsePrivateKey(privateKeyPem), SignatureAlgorithm.ES256)
            .compact()
    }

    private fun parsePrivateKey(pem: String): ECPrivateKey {
        val normalized = pem
            .replace("\\n", "\n")
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replace("\\s".toRegex(), "")
        val keySpec = PKCS8EncodedKeySpec(Base64.getDecoder().decode(normalized))
        return KeyFactory.getInstance("EC").generatePrivate(keySpec) as ECPrivateKey
    }

    private companion object {
        private const val CLIENT_SECRET_TTL_SECONDS = 60L * 60L * 24L * 180L
        private val logger = KotlinLogging.logger {}
    }
}

private data class AppleTokenResponse(
    @JsonProperty("refresh_token")
    val refreshToken: String? = null
)
