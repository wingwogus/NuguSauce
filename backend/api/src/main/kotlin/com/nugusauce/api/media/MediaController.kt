package com.nugusauce.api.media

import com.nugusauce.api.common.ApiResponse
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.MediaAssetService
import com.nugusauce.application.media.MediaCommand
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/media/images")
class MediaController(
    private val mediaAssetService: MediaAssetService
) {
    @PostMapping("/upload-intent")
    fun createImageUploadIntent(
        @AuthenticationPrincipal userId: String?,
        @Valid @RequestBody request: MediaRequests.CreateImageUploadIntentRequest
    ): ResponseEntity<ApiResponse<MediaResponses.ImageUploadIntentResponse>> {
        val result = mediaAssetService.createImageUploadIntent(
            MediaCommand.CreateImageUploadIntent(
                memberId = requireUserId(userId),
                contentType = request.contentType,
                byteSize = request.byteSize,
                fileExtension = request.fileExtension
            )
        )
        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.ok(MediaResponses.ImageUploadIntentResponse.from(result)))
    }

    @PostMapping("/{imageId}/complete")
    fun completeImageUpload(
        @AuthenticationPrincipal userId: String?,
        @PathVariable imageId: Long
    ): ResponseEntity<ApiResponse<MediaResponses.VerifiedImageResponse>> {
        val result = mediaAssetService.completeImageUpload(
            MediaCommand.CompleteImageUpload(
                memberId = requireUserId(userId),
                imageId = imageId
            )
        )
        return ResponseEntity.ok(ApiResponse.ok(MediaResponses.VerifiedImageResponse.from(result)))
    }

    private fun requireUserId(userId: String?): Long {
        return userId?.toLongOrNull() ?: throw BusinessException(ErrorCode.UNAUTHORIZED)
    }
}
