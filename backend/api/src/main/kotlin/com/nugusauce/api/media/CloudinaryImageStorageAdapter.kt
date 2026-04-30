package com.nugusauce.api.media

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.application.media.MediaResult
import com.nugusauce.application.media.VerifiedUpload
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import org.springframework.http.MediaType
import org.springframework.util.LinkedMultiValueMap
import org.springframework.web.client.RestClient
import org.springframework.web.client.RestClientResponseException
import org.springframework.web.util.UriUtils
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.time.Instant
import java.util.TreeMap

@Component
class CloudinaryImageStorageAdapter(
    @Value("\${cloudinary.cloud-name:}") private val cloudName: String,
    @Value("\${cloudinary.api-key:}") private val apiKey: String,
    @Value("\${cloudinary.api-secret:}") private val apiSecret: String
) : ImageStoragePort {
    private val restClient = RestClient.builder().build()

    override fun createUploadTarget(
        providerKey: String,
        contentType: String,
        expiresAt: Instant
    ): MediaResult.UploadTarget {
        requireConfigured()
        val paramsToSign = sortedMapOf(
            "overwrite" to "false",
            "public_id" to providerKey,
            "timestamp" to Instant.now().epochSecond.toString()
        )
        val signature = sign(paramsToSign)
        return MediaResult.UploadTarget(
            url = "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
            method = "POST",
            headers = emptyMap(),
            fields = paramsToSign + mapOf(
                "api_key" to apiKey,
                "signature" to signature
            ),
            fileField = "file",
            expiresAt = expiresAt
        )
    }

    override fun verifyUpload(providerKey: String): VerifiedUpload {
        requireConfigured()
        val resource = try {
            restClient.get()
                .uri(adminResourceUrl(providerKey))
                .headers { headers ->
                    headers.setBasicAuth(apiKey, apiSecret, StandardCharsets.UTF_8)
                }
                .retrieve()
                .body(CloudinaryResourceResponse::class.java)
                ?: throw providerUnavailable()
        } catch (e: RestClientResponseException) {
            if (e.statusCode.value() == 404) {
                throw BusinessException(ErrorCode.MEDIA_UPLOAD_NOT_FOUND)
            }
            throw providerUnavailable()
        }

        return VerifiedUpload(
            contentType = contentTypeFromFormat(resource.format),
            byteSize = resource.bytes,
            width = resource.width,
            height = resource.height
        )
    }

    override fun displayUrl(providerKey: String): String {
        requireConfigured()
        return "https://res.cloudinary.com/$cloudName/image/upload/f_auto,q_auto/${encodePublicId(providerKey)}"
    }

    override fun delete(providerKey: String) {
        requireConfigured()
        val paramsToSign = sortedMapOf(
            "invalidate" to "true",
            "public_id" to providerKey,
            "timestamp" to Instant.now().epochSecond.toString()
        )
        val form = LinkedMultiValueMap<String, String>().apply {
            paramsToSign.forEach { (key, value) -> add(key, value) }
            add("api_key", apiKey)
            add("signature", sign(paramsToSign))
        }
        try {
            restClient.post()
                .uri("https://api.cloudinary.com/v1_1/$cloudName/image/destroy")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .body(form)
                .retrieve()
                .toBodilessEntity()
        } catch (e: RestClientResponseException) {
            throw providerUnavailable()
        }
    }

    private fun requireConfigured() {
        if (cloudName.isBlank() || apiKey.isBlank() || apiSecret.isBlank()) {
            throw providerUnavailable()
        }
    }

    private fun adminResourceUrl(providerKey: String): String {
        return "https://api.cloudinary.com/v1_1/$cloudName/resources/image/upload/${encodePublicId(providerKey)}"
    }

    private fun encodePublicId(providerKey: String): String {
        return providerKey
            .split("/")
            .joinToString("/") { segment ->
                UriUtils.encodePathSegment(segment, StandardCharsets.UTF_8)
            }
    }

    private fun sign(params: Map<String, String>): String {
        val canonical = TreeMap(params)
            .entries
            .joinToString("&") { (key, value) -> "$key=$value" }
        val input = canonical + apiSecret
        val digest = MessageDigest.getInstance("SHA-1").digest(input.toByteArray(StandardCharsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }

    private fun contentTypeFromFormat(format: String): String {
        return when (format.lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "heic" -> "image/heic"
            "heif" -> "image/heif"
            else -> "image/${format.lowercase()}"
        }
    }

    private fun providerUnavailable(): BusinessException {
        return BusinessException(ErrorCode.MEDIA_PROVIDER_UNAVAILABLE)
    }

    private data class CloudinaryResourceResponse(
        val publicId: String? = null,
        val format: String,
        val bytes: Long,
        val width: Int?,
        val height: Int?
    )
}
