package com.nugusauce.application.media

import java.time.Instant

interface ImageStoragePort {
    fun createUploadTarget(
        providerKey: String,
        contentType: String,
        expiresAt: Instant
    ): MediaResult.UploadTarget

    fun verifyUpload(providerKey: String): VerifiedUpload

    fun displayUrl(providerKey: String): String

    fun delete(providerKey: String)
}

data class VerifiedUpload(
    val contentType: String,
    val byteSize: Long,
    val width: Int?,
    val height: Int?
)
