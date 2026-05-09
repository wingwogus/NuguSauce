package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.media.MediaAssetRepository
import com.nugusauce.domain.media.MediaAssetStatus
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.ingredient.Ingredient
import com.nugusauce.domain.recipe.ingredient.IngredientRepository
import com.nugusauce.domain.recipe.report.RecipeReportRepository
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.math.BigDecimal

@Service
@Transactional
class RecipeWriteService(
    private val memberRepository: MemberRepository,
    private val ingredientRepository: IngredientRepository,
    private val sauceRecipeRepository: SauceRecipeRepository,
    private val mediaAssetRepository: MediaAssetRepository,
    private val recipeFavoriteRepository: RecipeFavoriteRepository,
    private val recipeReportRepository: RecipeReportRepository,
    private val recipeReviewRepository: RecipeReviewRepository,
    private val imageUrlResolver: ImageUrlResolver
) {
    fun create(command: RecipeCommand.CreateRecipe): RecipeResult.RecipeDetail {
        val author = findMember(command.authorId)
        validateRecipe(command)

        val ingredients = loadIngredients(command.ingredients.map { it.ingredientId }.toSet())
        val imageAsset = command.imageId?.let { findAttachableImage(it, author) }

        val recipe = SauceRecipe(
            title = command.title.trim(),
            description = command.description.trim(),
            spiceLevel = USER_RECIPE_DEFAULT_SPICE_LEVEL,
            richnessLevel = USER_RECIPE_DEFAULT_RICHNESS_LEVEL,
            imageAsset = imageAsset,
            tips = command.tips?.trim()?.takeIf { it.isNotBlank() },
            author = author
        )

        command.ingredients.forEach { input ->
            recipe.addIngredient(
                ingredient = ingredients.getValue(input.ingredientId),
                amount = input.amount,
                unit = input.unit?.trim()?.takeIf { it.isNotBlank() },
                ratio = input.ratio
            )
        }

        val saved = sauceRecipeRepository.save(recipe)
        imageAsset?.attachToRecipe(saved.id)
        return RecipeResult.detail(
            saved,
            imageUrl = imageUrlResolver.recipeImageUrl(saved),
            authorProfileImageUrl = imageUrlResolver.memberProfileImageUrl(author)
        )
    }

    fun update(command: RecipeCommand.UpdateRecipe): RecipeResult.RecipeDetail {
        val author = findMember(command.authorId)
        validateRecipe(command.title, command.description, command.ingredients)
        val recipe = findEditableOwnedRecipe(command.recipeId, command.authorId)
        val ingredients = loadIngredients(command.ingredients.map { it.ingredientId }.toSet())
        val imageAsset = resolveUpdateImage(command.imageId, recipe, author)

        recipe.updateContent(
            title = command.title.trim(),
            description = command.description.trim(),
            tips = command.tips?.trim()?.takeIf { it.isNotBlank() },
            imageAsset = imageAsset
        )
        recipe.replaceIngredients(
            command.ingredients.map { input ->
                SauceRecipe.IngredientInput(
                    ingredient = ingredients.getValue(input.ingredientId),
                    amount = input.amount,
                    unit = input.unit?.trim()?.takeIf { it.isNotBlank() },
                    ratio = input.ratio
                )
            }
        )
        imageAsset?.attachToRecipe(recipe.id)

        return RecipeResult.detail(
            recipe,
            imageUrl = imageUrlResolver.recipeImageUrl(recipe),
            authorProfileImageUrl = imageUrlResolver.memberProfileImageUrl(author)
        )
    }

    fun delete(command: RecipeCommand.DeleteRecipe) {
        val recipe = findDeletableOwnedRecipe(command.recipeId, command.authorId)
        detachRecipeImage(recipe)
        recipeReportRepository.deleteAll(recipeReportRepository.findAllByRecipeId(recipe.id))
        recipeFavoriteRepository.deleteAll(recipeFavoriteRepository.findAllByRecipeId(recipe.id))
        recipeReviewRepository.deleteAll(recipeReviewRepository.findAllByRecipeId(recipe.id))
        sauceRecipeRepository.delete(recipe)
    }

    private fun findMember(memberId: Long): Member {
        return memberRepository.findById(memberId).orElseThrow {
            BusinessException(ErrorCode.USER_NOT_FOUND)
        }
    }

    private fun validateRecipe(command: RecipeCommand.CreateRecipe) {
        validateRecipe(command.title, command.description, command.ingredients)
    }

    private fun validateRecipe(
        title: String,
        description: String,
        ingredients: List<RecipeCommand.IngredientInput>
    ) {
        if (title.isBlank() || description.isBlank()) {
            throw BusinessException(ErrorCode.INVALID_INPUT)
        }
        if (ingredients.isEmpty()) {
            throw BusinessException(
                ErrorCode.INVALID_INPUT,
                detail = mapOf("field" to "ingredients", "reason" to "must not be empty")
            )
        }
        ingredients.forEach(::validateIngredientInput)
    }

    private fun findAttachableImage(imageId: Long, author: Member): MediaAsset {
        val asset = mediaAssetRepository.findById(imageId).orElseThrow {
            BusinessException(ErrorCode.MEDIA_ASSET_NOT_FOUND)
        }
        if (asset.owner.id != author.id) {
            throw BusinessException(ErrorCode.FORBIDDEN_MEDIA_ASSET)
        }
        if (asset.isAttached) {
            throw BusinessException(ErrorCode.MEDIA_ALREADY_ATTACHED)
        }
        if (asset.status != MediaAssetStatus.VERIFIED) {
            throw BusinessException(ErrorCode.MEDIA_NOT_VERIFIED)
        }
        return asset
    }

    private fun resolveUpdateImage(imageId: Long?, recipe: SauceRecipe, author: Member): MediaAsset? {
        val currentImage = recipe.imageAsset
        if (imageId == null || imageId == currentImage?.id) {
            return currentImage
        }

        val nextImage = findAttachableImage(imageId, author)
        currentImage?.detachFromRecipe(recipe.id)
        return nextImage
    }

    private fun detachRecipeImage(recipe: SauceRecipe) {
        val imageAsset = recipe.imageAsset ?: return
        imageAsset.detachFromRecipe(recipe.id)
        recipe.imageAsset = null
    }

    private fun findEditableOwnedRecipe(recipeId: Long, authorId: Long): SauceRecipe {
        val recipe = sauceRecipeRepository.findByIdAndAuthorId(recipeId, authorId)
            ?: throw BusinessException(ErrorCode.RECIPE_NOT_FOUND)
        if (recipe.visibility != RecipeVisibility.VISIBLE) {
            throw BusinessException(ErrorCode.RECIPE_NOT_FOUND)
        }
        return recipe
    }

    private fun findDeletableOwnedRecipe(recipeId: Long, authorId: Long): SauceRecipe {
        return sauceRecipeRepository.findByIdAndAuthorId(recipeId, authorId)
            ?: throw BusinessException(ErrorCode.RECIPE_NOT_FOUND)
    }

    private fun validateIngredientInput(input: RecipeCommand.IngredientInput) {
        val hasAmount = input.amount != null
        val hasRatio = input.ratio != null
        if (!hasAmount && !hasRatio) {
            throw BusinessException(ErrorCode.INVALID_RECIPE_INGREDIENT_AMOUNT)
        }
        if (input.amount != null && input.amount <= BigDecimal.ZERO) {
            throw BusinessException(ErrorCode.INVALID_RECIPE_INGREDIENT_AMOUNT)
        }
        if (input.ratio != null && input.ratio <= BigDecimal.ZERO) {
            throw BusinessException(ErrorCode.INVALID_RECIPE_INGREDIENT_AMOUNT)
        }
    }

    private fun loadIngredients(ids: Set<Long>): Map<Long, Ingredient> {
        val ingredients = ingredientRepository.findAllById(ids).associateBy { it.id }
        val missing = ids - ingredients.keys
        if (missing.isNotEmpty()) {
            throw BusinessException(
                ErrorCode.INGREDIENT_NOT_FOUND,
                detail = mapOf("ingredientIds" to missing.sorted())
            )
        }
        return ingredients
    }

    companion object {
        private const val USER_RECIPE_DEFAULT_SPICE_LEVEL = 0
        private const val USER_RECIPE_DEFAULT_RICHNESS_LEVEL = 0
    }
}
