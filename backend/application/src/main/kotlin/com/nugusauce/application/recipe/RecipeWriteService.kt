package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.media.MediaAssetRepository
import com.nugusauce.domain.media.MediaAssetStatus
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.ingredient.Ingredient
import com.nugusauce.domain.recipe.ingredient.IngredientRepository
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

    private fun findMember(memberId: Long): Member {
        return memberRepository.findById(memberId).orElseThrow {
            BusinessException(ErrorCode.USER_NOT_FOUND)
        }
    }

    private fun validateRecipe(command: RecipeCommand.CreateRecipe) {
        if (command.title.isBlank() || command.description.isBlank()) {
            throw BusinessException(ErrorCode.INVALID_INPUT)
        }
        if (command.ingredients.isEmpty()) {
            throw BusinessException(
                ErrorCode.INVALID_INPUT,
                detail = mapOf("field" to "ingredients", "reason" to "must not be empty")
            )
        }
        command.ingredients.forEach(::validateIngredientInput)
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
