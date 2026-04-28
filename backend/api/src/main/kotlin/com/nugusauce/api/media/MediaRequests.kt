package com.nugusauce.api.media

import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size

object MediaRequests {
    data class CreateImageUploadIntentRequest(
        @field:NotBlank(message = "이미지 contentType이 필요합니다")
        @field:Size(max = 120, message = "이미지 contentType은 120자 이하여야 합니다")
        val contentType: String,

        @field:Min(value = 1, message = "이미지 크기가 올바르지 않습니다")
        val byteSize: Long,

        @field:Size(max = 16, message = "파일 확장자는 16자 이하여야 합니다")
        val fileExtension: String? = null
    )
}
