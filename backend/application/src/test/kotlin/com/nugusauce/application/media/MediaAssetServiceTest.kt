package com.nugusauce.application.media

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.media.MediaAssetRepository
import com.nugusauce.domain.media.MediaAssetStatus
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import java.time.Instant
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class MediaAssetServiceTest {
    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var mediaAssetRepository: MediaAssetRepository

    private lateinit var imageStoragePort: FakeImageStoragePort
    private lateinit var service: MediaAssetService

    @BeforeEach
    fun setUp() {
        imageStoragePort = FakeImageStoragePort()
        service = MediaAssetService(memberRepository, mediaAssetRepository, imageStoragePort)
    }

    @Test
    fun `createImageUploadIntent stores pending asset and returns direct upload target`() {
        val member = Member(1L, "user@example.test", null, nickname = "소스장인")
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(mediaAssetRepository.save(Mockito.any(MediaAsset::class.java)))
            .thenAnswer {
                val asset = it.getArgument<MediaAsset>(0)
                MediaAsset(
                    id = 10L,
                    owner = asset.owner,
                    provider = asset.provider,
                    providerKey = asset.providerKey,
                    contentType = asset.contentType,
                    byteSize = asset.byteSize
                )
            }

        val result = service.createImageUploadIntent(
            MediaCommand.CreateImageUploadIntent(
                memberId = 1L,
                contentType = "image/jpeg",
                byteSize = 2000L,
                fileExtension = "jpg"
            )
        )

        assertEquals(10L, result.imageId)
        assertEquals("POST", result.upload.method)
        assertEquals("file", result.upload.fileField)
        assertTrue(result.upload.fields.containsKey("signature"))
        assertEquals(MediaAssetService.MAX_IMAGE_BYTES, result.constraints.maxBytes)
    }

    @Test
    fun `completeImageUpload verifies cloud asset and marks it verified`() {
        val member = Member(1L, "user@example.test", null, nickname = "소스장인")
        val asset = MediaAsset(
            id = 10L,
            owner = member,
            provider = com.nugusauce.domain.media.MediaProvider.CLOUDINARY,
            providerKey = "nugusauce/recipes/1/image",
            contentType = "image/jpeg",
            byteSize = 2000L
        )
        `when`(mediaAssetRepository.findById(10L)).thenReturn(Optional.of(asset))

        val result = service.completeImageUpload(MediaCommand.CompleteImageUpload(1L, 10L))

        assertEquals("https://cdn.example.test/nugusauce/recipes/1/image", result.imageUrl)
        assertEquals(MediaAssetStatus.VERIFIED, asset.status)
        assertEquals(800, asset.width)
        assertEquals(600, asset.height)
    }

    @Test
    fun `createImageUploadIntent rejects oversized image`() {
        `when`(memberRepository.findById(1L)).thenReturn(
            Optional.of(Member(1L, "user@example.test", null))
        )

        val exception = assertThrows(BusinessException::class.java) {
            service.createImageUploadIntent(
                MediaCommand.CreateImageUploadIntent(
                    memberId = 1L,
                    contentType = "image/jpeg",
                    byteSize = MediaAssetService.MAX_IMAGE_BYTES + 1L
                )
            )
        }

        assertEquals(ErrorCode.MEDIA_TOO_LARGE, exception.errorCode)
    }

    private class FakeImageStoragePort : ImageStoragePort {
        override fun createUploadTarget(
            providerKey: String,
            contentType: String,
            expiresAt: Instant
        ): MediaResult.UploadTarget {
            return MediaResult.UploadTarget(
                url = "https://upload.example.test",
                method = "POST",
                headers = emptyMap(),
                fields = mapOf(
                    "public_id" to providerKey,
                    "signature" to "signed"
                ),
                fileField = "file",
                expiresAt = expiresAt
            )
        }

        override fun verifyUpload(providerKey: String): VerifiedUpload {
            return VerifiedUpload(
                contentType = "image/jpeg",
                byteSize = 2000L,
                width = 800,
                height = 600
            )
        }

        override fun displayUrl(providerKey: String): String {
            return "https://cdn.example.test/$providerKey"
        }

        override fun delete(providerKey: String) {
            throw UnsupportedOperationException()
        }
    }
}
