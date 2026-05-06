package com.nugusauce.api.recipe

import com.nugusauce.api.common.ApiResponse
import com.nugusauce.application.consent.ConsentService
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.recipe.RecipeCommand
import com.nugusauce.application.recipe.RecipeFavoriteService
import com.nugusauce.application.recipe.RecipeModerationService
import com.nugusauce.application.recipe.RecipeQueryService
import com.nugusauce.application.recipe.RecipeReviewService
import com.nugusauce.application.recipe.RecipeWriteService
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1")
class RecipeController(
    private val recipeQueryService: RecipeQueryService,
    private val recipeWriteService: RecipeWriteService,
    private val recipeReviewService: RecipeReviewService,
    private val recipeModerationService: RecipeModerationService,
    private val recipeFavoriteService: RecipeFavoriteService,
    private val consentService: ConsentService
) {
    @GetMapping("/recipes")
    fun searchRecipes(
        @AuthenticationPrincipal userId: String?,
        @RequestParam(required = false) q: String?,
        @RequestParam(required = false) tagIds: List<String>?,
        @RequestParam(required = false) ingredientIds: List<String>?,
        @RequestParam(required = false) sort: String?
    ): ResponseEntity<ApiResponse<List<RecipeResponses.RecipeSummaryResponse>>> {
        val results = recipeQueryService.search(
            RecipeCommand.SearchRecipes(
                q = q,
                tagIds = parseIds("tagIds", tagIds),
                ingredientIds = parseIds("ingredientIds", ingredientIds),
                sort = parseSort(sort),
                viewerMemberId = userId?.toLongOrNull()
            )
        )
        return ResponseEntity.ok(ApiResponse.ok(results.map(RecipeResponses.RecipeSummaryResponse::from)))
    }

    @GetMapping("/recipes/{recipeId}")
    fun getRecipe(
        @AuthenticationPrincipal userId: String?,
        @PathVariable recipeId: Long
    ): ResponseEntity<ApiResponse<RecipeResponses.RecipeDetailResponse>> {
        val result = recipeQueryService.getDetail(recipeId, userId?.toLongOrNull())
        return ResponseEntity.ok(ApiResponse.ok(RecipeResponses.RecipeDetailResponse.from(result)))
    }

    @PostMapping("/recipes")
    fun createRecipe(
        @AuthenticationPrincipal userId: String?,
        @Valid @RequestBody request: RecipeRequests.CreateRecipeRequest
    ): ResponseEntity<ApiResponse<RecipeResponses.RecipeDetailResponse>> {
        rejectAuthorTasteClassification(request)
        rejectDeprecatedImageUrl(request)
        val memberId = requireUserId(userId)
        consentService.requireRequiredConsents(memberId)
        val result = recipeWriteService.create(
            RecipeCommand.CreateRecipe(
                authorId = memberId,
                title = request.title,
                description = request.description,
                imageId = request.imageId,
                tips = request.tips,
                ingredients = request.ingredients.map {
                    RecipeCommand.IngredientInput(
                        ingredientId = it.ingredientId,
                        amount = it.amount,
                        unit = it.unit,
                        ratio = it.ratio
                    )
                }
            )
        )
        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.ok(RecipeResponses.RecipeDetailResponse.from(result)))
    }

    @GetMapping("/ingredients")
    fun listIngredients(): ResponseEntity<ApiResponse<List<RecipeResponses.IngredientResponse>>> {
        val results = recipeQueryService.listIngredients()
        return ResponseEntity.ok(ApiResponse.ok(results.map(RecipeResponses.IngredientResponse::from)))
    }

    @GetMapping("/tags")
    fun listTags(): ResponseEntity<ApiResponse<List<RecipeResponses.TagResponse>>> {
        val results = recipeQueryService.listTags()
        return ResponseEntity.ok(ApiResponse.ok(results.map(RecipeResponses.TagResponse::from)))
    }

    @PostMapping("/recipes/{recipeId}/reviews")
    fun createReview(
        @AuthenticationPrincipal userId: String?,
        @PathVariable recipeId: Long,
        @Valid @RequestBody request: RecipeRequests.CreateReviewRequest
    ): ResponseEntity<ApiResponse<RecipeResponses.ReviewResponse>> {
        val memberId = requireUserId(userId)
        consentService.requireRequiredConsents(memberId)
        val result = recipeReviewService.create(
            RecipeCommand.CreateReview(
                authorId = memberId,
                recipeId = recipeId,
                rating = request.rating,
                text = request.text,
                tasteTagIds = request.tasteTagIds
            )
        )
        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.ok(RecipeResponses.ReviewResponse.from(result)))
    }

    @GetMapping("/recipes/{recipeId}/reviews")
    fun listReviews(
        @PathVariable recipeId: Long
    ): ResponseEntity<ApiResponse<List<RecipeResponses.ReviewResponse>>> {
        val results = recipeQueryService.listReviews(recipeId)
        return ResponseEntity.ok(ApiResponse.ok(results.map(RecipeResponses.ReviewResponse::from)))
    }

    @PostMapping("/recipes/{recipeId}/reports")
    fun createReport(
        @AuthenticationPrincipal userId: String?,
        @PathVariable recipeId: Long,
        @Valid @RequestBody request: RecipeRequests.CreateReportRequest
    ): ResponseEntity<ApiResponse<RecipeResponses.ReportResponse>> {
        val memberId = requireUserId(userId)
        consentService.requireRequiredConsents(memberId)
        val result = recipeModerationService.report(
            RecipeCommand.CreateReport(
                reporterId = memberId,
                recipeId = recipeId,
                reason = request.reason
            )
        )
        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.ok(RecipeResponses.ReportResponse.from(result)))
    }

    @GetMapping("/me/recipes")
    fun listMyRecipes(
        @AuthenticationPrincipal userId: String?
    ): ResponseEntity<ApiResponse<List<RecipeResponses.RecipeSummaryResponse>>> {
        val results = recipeFavoriteService.listMyRecipes(
            RecipeCommand.MemberRecipes(requireUserId(userId))
        )
        return ResponseEntity.ok(ApiResponse.ok(results.map(RecipeResponses.RecipeSummaryResponse::from)))
    }

    @GetMapping("/me/favorite-recipes")
    fun listFavoriteRecipes(
        @AuthenticationPrincipal userId: String?
    ): ResponseEntity<ApiResponse<List<RecipeResponses.RecipeSummaryResponse>>> {
        val results = recipeFavoriteService.listFavorites(
            RecipeCommand.MemberRecipes(requireUserId(userId))
        )
        return ResponseEntity.ok(ApiResponse.ok(results.map(RecipeResponses.RecipeSummaryResponse::from)))
    }

    @PostMapping("/me/favorite-recipes/{recipeId}")
    fun addFavoriteRecipe(
        @AuthenticationPrincipal userId: String?,
        @PathVariable recipeId: Long
    ): ResponseEntity<ApiResponse<RecipeResponses.FavoriteResponse>> {
        val result = recipeFavoriteService.addFavorite(
            RecipeCommand.FavoriteRecipe(
                memberId = requireUserId(userId),
                recipeId = recipeId
            )
        )
        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.ok(RecipeResponses.FavoriteResponse.from(result)))
    }

    @DeleteMapping("/me/favorite-recipes/{recipeId}")
    fun deleteFavoriteRecipe(
        @AuthenticationPrincipal userId: String?,
        @PathVariable recipeId: Long
    ): ResponseEntity<ApiResponse<Unit>> {
        recipeFavoriteService.removeFavorite(
            RecipeCommand.FavoriteRecipe(
                memberId = requireUserId(userId),
                recipeId = recipeId
            )
        )
        return ResponseEntity.ok(ApiResponse.empty(Unit))
    }

    private fun requireUserId(userId: String?): Long {
        return userId?.toLongOrNull() ?: throw BusinessException(ErrorCode.UNAUTHORIZED)
    }

    private fun rejectAuthorTasteClassification(request: RecipeRequests.CreateRecipeRequest) {
        if (!request.containsAuthorTasteClassification()) {
            return
        }
        throw BusinessException(
            ErrorCode.INVALID_INPUT,
            detail = mapOf(
                "fields" to listOf("spiceLevel", "richnessLevel", "tagIds"),
                "reason" to "authors can only submit sauce composition; taste classification comes from reviews"
            )
        )
    }

    private fun rejectDeprecatedImageUrl(request: RecipeRequests.CreateRecipeRequest) {
        if (request.imageUrl == null) {
            return
        }
        throw BusinessException(
            ErrorCode.INVALID_INPUT,
            detail = mapOf(
                "field" to "imageUrl",
                "reason" to "use imageId from media upload completion"
            )
        )
    }

    private fun parseSort(sort: String?): RecipeCommand.RecipeSort {
        return try {
            RecipeCommand.RecipeSort.from(sort)
        } catch (e: IllegalArgumentException) {
            throw BusinessException(
                ErrorCode.INVALID_INPUT,
                detail = mapOf("field" to "sort", "reason" to "unsupported sort")
            )
        }
    }

    private fun parseIds(field: String, rawValues: List<String>?): List<Long> {
        return rawValues.orEmpty()
            .flatMap { it.split(",") }
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .map {
                it.toLongOrNull() ?: throw BusinessException(
                    ErrorCode.INVALID_INPUT,
                    detail = mapOf("field" to field, "reason" to "must contain numeric IDs")
                )
            }
    }
}
