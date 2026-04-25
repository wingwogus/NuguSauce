package com.nugusauce.api.recipe

import com.nugusauce.api.common.ApiResponse
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.recipe.RecipeCommand
import com.nugusauce.application.recipe.RecipeModerationService
import jakarta.validation.Valid
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/admin/recipes")
class AdminRecipeController(
    private val recipeModerationService: RecipeModerationService
) {
    @PatchMapping("/{recipeId}/visibility")
    fun updateVisibility(
        @PathVariable recipeId: Long,
        @Valid @RequestBody request: RecipeRequests.UpdateVisibilityRequest
    ): ResponseEntity<ApiResponse<RecipeResponses.RecipeDetailResponse>> {
        val visibility = try {
            RecipeCommand.Visibility.from(request.visibility)
        } catch (e: IllegalArgumentException) {
            throw BusinessException(
                ErrorCode.INVALID_INPUT,
                detail = mapOf("field" to "visibility", "reason" to "must be VISIBLE or HIDDEN")
            )
        }

        val result = recipeModerationService.updateVisibility(
            RecipeCommand.UpdateVisibility(
                recipeId = recipeId,
                visibility = visibility
            )
        )
        return ResponseEntity.ok(ApiResponse.ok(RecipeResponses.RecipeDetailResponse.from(result)))
    }
}
