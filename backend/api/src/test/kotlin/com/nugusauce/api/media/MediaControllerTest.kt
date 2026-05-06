package com.nugusauce.api.media

import com.nugusauce.api.exception.GlobalExceptionHandler
import com.nugusauce.application.consent.ConsentService
import com.nugusauce.application.media.MediaAssetService
import com.nugusauce.application.media.MediaCommand
import com.nugusauce.application.media.MediaResult
import com.nugusauce.application.security.TokenProvider
import org.hamcrest.Matchers.equalTo
import org.junit.jupiter.api.Test
import org.mockito.Mockito.`when`
import org.mockito.Mockito.verify
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest
import org.springframework.boot.test.mock.mockito.MockBean
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.Instant

@WebMvcTest(MediaController::class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler::class)
class MediaControllerTest(
    @Autowired private val mockMvc: MockMvc
) {
    @MockBean
    private lateinit var mediaAssetService: MediaAssetService

    @MockBean
    private lateinit var consentService: ConsentService

    @MockBean
    private lateinit var tokenProvider: TokenProvider

    @Test
    fun `create upload intent returns signed direct upload target`() {
        `when`(
            mediaAssetService.createImageUploadIntent(
                MediaCommand.CreateImageUploadIntent(
                    memberId = 1L,
                    contentType = "image/jpeg",
                    byteSize = 2000L,
                    fileExtension = "jpg"
                )
            )
        )
            .thenReturn(
                MediaResult.ImageUploadIntent(
                    imageId = 10L,
                    upload = MediaResult.UploadTarget(
                        url = "https://api.cloudinary.com/v1_1/demo/image/upload",
                        method = "POST",
                        headers = emptyMap(),
                        fields = mapOf(
                            "api_key" to "api-key",
                            "public_id" to "nugusauce/recipes/1/image",
                            "timestamp" to "1777399200",
                            "signature" to "signature"
                        ),
                        fileField = "file",
                        expiresAt = Instant.parse("2026-04-28T14:30:00Z")
                    ),
                    constraints = MediaResult.ImageUploadConstraints(
                        maxBytes = 5_242_880L,
                        allowedContentTypes = listOf("image/jpeg", "image/png", "image/heic", "image/heif")
                    )
                )
            )

        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken("1", null)
        try {
            mockMvc.perform(
                post("/api/v1/media/images/upload-intent")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("""{"contentType":"image/jpeg","byteSize":2000,"fileExtension":"jpg"}""")
            )
                .andExpect(status().isCreated)
                .andExpect(jsonPath("$.data.imageId", equalTo(10)))
                .andExpect(jsonPath("$.data.upload.method", equalTo("POST")))
                .andExpect(jsonPath("$.data.upload.fileField", equalTo("file")))
                .andExpect(jsonPath("$.data.upload.fields.signature", equalTo("signature")))
                .andExpect(jsonPath("$.data.constraints.maxBytes", equalTo(5_242_880)))
            verify(consentService).requireRequiredConsents(1L)
        } finally {
            SecurityContextHolder.clearContext()
        }
    }

    @Test
    fun `complete upload returns verified image`() {
        `when`(
            mediaAssetService.completeImageUpload(
                MediaCommand.CompleteImageUpload(
                    memberId = 1L,
                    imageId = 10L
                )
            )
        )
            .thenReturn(
                MediaResult.VerifiedImage(
                    imageId = 10L,
                    imageUrl = "https://res.cloudinary.com/demo/image/upload/f_auto,q_auto/nugusauce/recipes/1/image",
                    width = 800,
                    height = 600
                )
            )

        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken("1", null)
        try {
            mockMvc.perform(post("/api/v1/media/images/10/complete"))
                .andExpect(status().isOk)
                .andExpect(jsonPath("$.data.imageId", equalTo(10)))
                .andExpect(jsonPath("$.data.width", equalTo(800)))
                .andExpect(jsonPath("$.data.height", equalTo(600)))
        } finally {
            SecurityContextHolder.clearContext()
        }
    }
}
