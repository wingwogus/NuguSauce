package com.nugusauce.api.recipe

import jakarta.validation.Valid
import jakarta.validation.constraints.DecimalMin
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotEmpty
import jakarta.validation.constraints.Size
import java.math.BigDecimal

object RecipeRequests {
    data class IngredientRequest(
        @field:Min(value = 1, message = "재료 ID가 올바르지 않습니다")
        val ingredientId: Long,

        @field:DecimalMin(value = "0.0", inclusive = false, message = "재료 양은 0보다 커야 합니다")
        val amount: BigDecimal? = null,

        @field:Size(max = 32, message = "단위는 32자 이하여야 합니다")
        val unit: String? = null,

        @field:DecimalMin(value = "0.0", inclusive = false, message = "재료 비율은 0보다 커야 합니다")
        val ratio: BigDecimal? = null
    )

    data class CreateRecipeRequest(
        @field:NotBlank(message = "레시피 제목을 입력해주세요")
        @field:Size(max = 120, message = "레시피 제목은 120자 이하여야 합니다")
        val title: String,

        @field:NotBlank(message = "레시피 설명을 입력해주세요")
        @field:Size(max = 1000, message = "레시피 설명은 1000자 이하여야 합니다")
        val description: String,

        @field:Size(max = 2048, message = "이미지 URL은 2048자 이하여야 합니다")
        val imageUrl: String? = null,

        @field:Min(value = 1, message = "이미지 ID가 올바르지 않습니다")
        val imageId: Long? = null,

        @field:Size(max = 1000, message = "팁은 1000자 이하여야 합니다")
        val tips: String? = null,

        @field:NotEmpty(message = "재료를 하나 이상 입력해주세요")
        @field:Valid
        val ingredients: List<IngredientRequest>,

        val spiceLevel: Int? = null,

        val richnessLevel: Int? = null,

        val tagIds: List<Long>? = null
    ) {
        fun containsAuthorTasteClassification(): Boolean {
            return spiceLevel != null || richnessLevel != null || tagIds != null
        }
    }

    data class CreateReviewRequest(
        @field:Min(value = 1, message = "평점은 1 이상이어야 합니다")
        @field:Max(value = 5, message = "평점은 5 이하여야 합니다")
        val rating: Int,

        @field:Size(max = 1000, message = "리뷰는 1000자 이하여야 합니다")
        val text: String? = null,

        val tasteTagIds: List<Long> = emptyList()
    )

    data class CreateReportRequest(
        @field:NotBlank(message = "신고 사유를 입력해주세요")
        @field:Size(max = 500, message = "신고 사유는 500자 이하여야 합니다")
        val reason: String
    )

    data class UpdateVisibilityRequest(
        @field:NotBlank(message = "공개 상태를 입력해주세요")
        val visibility: String
    )
}
