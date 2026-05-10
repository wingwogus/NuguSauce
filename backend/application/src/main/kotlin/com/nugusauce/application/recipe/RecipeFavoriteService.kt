package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.favorite.RecipeFavorite
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Instant

@Service
@Transactional
class RecipeFavoriteService(
    private val memberRepository: MemberRepository,
    private val sauceRecipeRepository: SauceRecipeRepository,
    private val recipeFavoriteRepository: RecipeFavoriteRepository,
    private val imageUrlResolver: ImageUrlResolver
) {
    @Transactional(readOnly = true)
    fun listMyRecipes(command: RecipeCommand.MemberRecipes): List<RecipeResult.RecipeSummary> {
        ensureMember(command.memberId)
        val recipes = sauceRecipeRepository.findAllByAuthorIdAndVisibilityOrderByCreatedAtDesc(
            command.memberId,
            RecipeVisibility.VISIBLE
        )
        return summarizeRecipes(
            recipes,
            favoriteRecipeIds = loadFavoriteRecipeIds(command.memberId, recipes.map { it.id })
        )
    }

    @Transactional(readOnly = true)
    fun listFavorites(command: RecipeCommand.MemberRecipes): List<RecipeResult.RecipeSummary> {
        ensureMember(command.memberId)
        val recipes = recipeFavoriteRepository.findAllByMemberIdOrderByCreatedAtDesc(command.memberId)
            .map { it.recipe }
            .filter { it.visibility == RecipeVisibility.VISIBLE }
        return summarizeRecipes(
            recipes,
            favoriteRecipeIds = recipes.map { it.id }.toSet()
        )
    }

    fun addFavorite(command: RecipeCommand.FavoriteRecipe): RecipeResult.FavoriteItem {
        val member = ensureMember(command.memberId)
        val recipe = findVisibleRecipe(command.recipeId)
        if (recipeFavoriteRepository.existsByRecipeAndMember(command.recipeId, command.memberId)) {
            throw BusinessException(ErrorCode.DUPLICATE_FAVORITE)
        }

        val favorite = recipeFavoriteRepository.save(
            RecipeFavorite(
                recipe = recipe,
                member = member
            )
        )
        sauceRecipeRepository.incrementFavoriteCount(command.recipeId, favorite.createdAt)

        return RecipeResult.FavoriteItem(
            recipeId = command.recipeId,
            createdAt = favorite.createdAt
        )
    }

    fun removeFavorite(command: RecipeCommand.FavoriteRecipe) {
        ensureMember(command.memberId)
        val favorite = recipeFavoriteRepository.findByRecipeAndMember(command.recipeId, command.memberId)
            ?: throw BusinessException(ErrorCode.FAVORITE_NOT_FOUND)
        val recipeId = favorite.recipe.id
        recipeFavoriteRepository.delete(favorite)
        sauceRecipeRepository.decrementFavoriteCount(recipeId, Instant.now())
    }

    private fun ensureMember(memberId: Long): Member {
        return memberRepository.findById(memberId).orElseThrow {
            BusinessException(ErrorCode.USER_NOT_FOUND)
        }
    }

    private fun findVisibleRecipe(recipeId: Long): SauceRecipe {
        val recipe = sauceRecipeRepository.findById(recipeId).orElseThrow {
            BusinessException(ErrorCode.RECIPE_NOT_FOUND)
        }
        if (recipe.visibility != RecipeVisibility.VISIBLE) {
            throw BusinessException(ErrorCode.HIDDEN_RECIPE)
        }
        return recipe
    }

    private fun summarizeRecipes(
        recipes: List<SauceRecipe>,
        favoriteRecipeIds: Set<Long> = emptySet()
    ): List<RecipeResult.RecipeSummary> {
        return recipes.map { recipe ->
            RecipeResult.summary(
                recipe,
                isFavorite = recipe.id in favoriteRecipeIds,
                imageUrl = imageUrlResolver.recipeImageUrl(recipe)
            )
        }
    }

    private fun loadFavoriteRecipeIds(memberId: Long, recipeIds: Collection<Long>): Set<Long> {
        if (recipeIds.isEmpty()) {
            return emptySet()
        }
        return recipeFavoriteRepository.findRecipeIdsByMemberAndRecipeIds(memberId, recipeIds.toSet())
    }

}
