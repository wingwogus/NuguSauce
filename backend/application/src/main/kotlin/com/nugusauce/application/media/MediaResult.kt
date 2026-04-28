package com.nugusauce.application.media

import java.time.Instant

object MediaResult {
    data class ImageUploadIntent(
        val imageId: Long,
        val upload: UploadTarget,
        val constraints: ImageUploadConstraints
    )

    data class UploadTarget(
        val url: String,
        val method: String,
        val headers: Map<String, String>,
        val fields: Map<String, String>,
        val fileField: String,
        val expiresAt: Instant
    )

    data class ImageUploadConstraints(
        val maxBytes: Long,
        val allowedContentTypes: List<String>
    )

    data class VerifiedImage(
        val imageId: Long,
        val imageUrl: String,
        val width: Int?,
        val height: Int?
    )
}
