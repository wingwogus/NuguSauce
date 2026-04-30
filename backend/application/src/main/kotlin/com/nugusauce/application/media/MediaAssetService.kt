package com.nugusauce.application.media

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.media.MediaAssetRepository
import com.nugusauce.domain.media.MediaAssetStatus
import com.nugusauce.domain.media.MediaProvider
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Duration
import java.time.Instant
import java.util.UUID

@Service
@Transactional
class MediaAssetService(
    private val memberRepository: MemberRepository,
    private val mediaAssetRepository: MediaAssetRepository,
    private val imageStoragePort: ImageStoragePort
) {
    fun createImageUploadIntent(command: MediaCommand.CreateImageUploadIntent): MediaResult.ImageUploadIntent {
        val owner = findMember(command.memberId)
        val contentType = command.contentType.trim().lowercase()
        validateImageContentType(contentType)
        validateImageByteSize(command.byteSize)

        val asset = mediaAssetRepository.save(
            MediaAsset(
                owner = owner,
                provider = MediaProvider.CLOUDINARY,
                providerKey = nextProviderKey(owner, command.fileExtension),
                contentType = contentType,
                byteSize = command.byteSize
            )
        )
        val expiresAt = Instant.now().plus(UPLOAD_INTENT_TTL)
        return MediaResult.ImageUploadIntent(
            imageId = asset.id,
            upload = imageStoragePort.createUploadTarget(
                providerKey = asset.providerKey,
                contentType = contentType,
                expiresAt = expiresAt
            ),
            constraints = MediaResult.ImageUploadConstraints(
                maxBytes = MAX_IMAGE_BYTES,
                allowedContentTypes = ALLOWED_IMAGE_CONTENT_TYPES.toList()
            )
        )
    }

    fun completeImageUpload(command: MediaCommand.CompleteImageUpload): MediaResult.VerifiedImage {
        val asset = findOwnedAsset(command.imageId, command.memberId)
        if (asset.status == MediaAssetStatus.ATTACHED) {
            throw BusinessException(ErrorCode.MEDIA_ALREADY_ATTACHED)
        }

        val verified = imageStoragePort.verifyUpload(asset.providerKey)
        validateImageContentType(verified.contentType.lowercase())
        validateImageByteSize(verified.byteSize)
        asset.markVerified(
            contentType = verified.contentType.lowercase(),
            byteSize = verified.byteSize,
            width = verified.width,
            height = verified.height
        )
        return MediaResult.VerifiedImage(
            imageId = asset.id,
            imageUrl = imageStoragePort.displayUrl(asset.providerKey),
            width = asset.width,
            height = asset.height
        )
    }

    private fun findMember(memberId: Long): Member {
        return memberRepository.findById(memberId).orElseThrow {
            BusinessException(ErrorCode.USER_NOT_FOUND)
        }
    }

    private fun findOwnedAsset(imageId: Long, memberId: Long): MediaAsset {
        val asset = mediaAssetRepository.findById(imageId).orElseThrow {
            BusinessException(ErrorCode.MEDIA_ASSET_NOT_FOUND)
        }
        if (asset.owner.id != memberId) {
            throw BusinessException(ErrorCode.FORBIDDEN_MEDIA_ASSET)
        }
        return asset
    }

    private fun validateImageContentType(contentType: String) {
        if (contentType !in ALLOWED_IMAGE_CONTENT_TYPES) {
            throw BusinessException(
                ErrorCode.UNSUPPORTED_MEDIA_TYPE,
                detail = mapOf(
                    "field" to "contentType",
                    "allowed" to ALLOWED_IMAGE_CONTENT_TYPES.toList()
                )
            )
        }
    }

    private fun validateImageByteSize(byteSize: Long) {
        if (byteSize <= 0 || byteSize > MAX_IMAGE_BYTES) {
            throw BusinessException(
                ErrorCode.MEDIA_TOO_LARGE,
                detail = mapOf("maxBytes" to MAX_IMAGE_BYTES)
            )
        }
    }

    private fun nextProviderKey(owner: Member, fileExtension: String?): String {
        val suffix = normalizeExtension(fileExtension)
            ?.let { "-$it" }
            ?: ""
        return "nugusauce/images/${owner.id}/${UUID.randomUUID()}$suffix"
    }

    private fun normalizeExtension(fileExtension: String?): String? {
        val normalized = fileExtension
            ?.trim()
            ?.removePrefix(".")
            ?.lowercase()
            ?.takeIf { it.isNotBlank() }
            ?: return null
        return normalized.take(MAX_EXTENSION_LENGTH)
    }

    companion object {
        const val MAX_IMAGE_BYTES: Long = 5L * 1024L * 1024L
        private const val MAX_EXTENSION_LENGTH = 12
        private val UPLOAD_INTENT_TTL: Duration = Duration.ofMinutes(15)
        val ALLOWED_IMAGE_CONTENT_TYPES: Set<String> = linkedSetOf(
            "image/jpeg",
            "image/png",
            "image/heic",
            "image/heif"
        )
    }
}
