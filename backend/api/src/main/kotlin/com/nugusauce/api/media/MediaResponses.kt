package com.nugusauce.api.media

import com.nugusauce.application.media.MediaResult
import java.time.Instant

object MediaResponses {
    data class ImageUploadIntentResponse(
        val imageId: Long,
        val upload: UploadTargetResponse,
        val constraints: ImageUploadConstraintsResponse
    ) {
        companion object {
            fun from(result: MediaResult.ImageUploadIntent): ImageUploadIntentResponse {
                return ImageUploadIntentResponse(
                    imageId = result.imageId,
                    upload = UploadTargetResponse.from(result.upload),
                    constraints = ImageUploadConstraintsResponse.from(result.constraints)
                )
            }
        }
    }

    data class UploadTargetResponse(
        val url: String,
        val method: String,
        val headers: Map<String, String>,
        val fields: Map<String, String>,
        val fileField: String,
        val expiresAt: Instant
    ) {
        companion object {
            fun from(result: MediaResult.UploadTarget): UploadTargetResponse {
                return UploadTargetResponse(
                    url = result.url,
                    method = result.method,
                    headers = result.headers,
                    fields = result.fields,
                    fileField = result.fileField,
                    expiresAt = result.expiresAt
                )
            }
        }
    }

    data class ImageUploadConstraintsResponse(
        val maxBytes: Long,
        val allowedContentTypes: List<String>
    ) {
        companion object {
            fun from(result: MediaResult.ImageUploadConstraints): ImageUploadConstraintsResponse {
                return ImageUploadConstraintsResponse(
                    maxBytes = result.maxBytes,
                    allowedContentTypes = result.allowedContentTypes
                )
            }
        }
    }

    data class VerifiedImageResponse(
        val imageId: Long,
        val imageUrl: String,
        val width: Int?,
        val height: Int?
    ) {
        companion object {
            fun from(result: MediaResult.VerifiedImage): VerifiedImageResponse {
                return VerifiedImageResponse(
                    imageId = result.imageId,
                    imageUrl = result.imageUrl,
                    width = result.width,
                    height = result.height
                )
            }
        }
    }
}
