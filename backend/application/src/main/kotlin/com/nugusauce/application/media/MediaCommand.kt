package com.nugusauce.application.media

object MediaCommand {
    data class CreateImageUploadIntent(
        val memberId: Long,
        val contentType: String,
        val byteSize: Long,
        val fileExtension: String? = null
    )

    data class CompleteImageUpload(
        val memberId: Long,
        val imageId: Long
    )
}
