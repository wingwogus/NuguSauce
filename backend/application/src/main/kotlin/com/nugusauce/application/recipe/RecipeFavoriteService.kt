package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.favorite.RecipeFavorite
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class RecipeFavoriteService(
    private val memberRepository: MemberRepository,
    private val sauceRecipeRepository: SauceRecipeRepository,
    private val recipeFavoriteRepository: RecipeFavoriteRepository,
    private val recipeReviewRepository: RecipeReviewRepository,
    private val recipeImageUrlResolver: RecipeImageUrlResolver
) {
    @Transactional(readOnly = true)
    fun listMyRecipes(command: RecipeCommand.MemberRecipes): List<RecipeResult.RecipeSummary> {
        ensureMember(command.memberId)
        val recipes = sauceRecipeRepository.findAllByAuthorIdOrderByCreatedAtDesc(command.memberId)
        return summarizeWithReviewTags(recipes)
    }

    @Transactional(readOnly = true)
    fun listFavorites(command: RecipeCommand.MemberRecipes): List<RecipeResult.RecipeSummary> {
        ensureMember(command.memberId)
        val recipes = recipeFavoriteRepository.findAllByMemberIdOrderByCreatedAtDesc(command.memberId)
            .map { it.recipe }
            .filter { it.visibility == RecipeVisibility.VISIBLE }
        return summarizeWithReviewTags(recipes)
    }

    fun addFavorite(command: RecipeCommand.FavoriteRecipe): RecipeResult.FavoriteItem {
        val member = ensureMember(command.memberId)
        val recipe = findVisibleRecipe(command.recipeId)
        if (recipeFavoriteRepository.existsByRecipeAndMember(command.recipeId, command.memberId)) {
            throw BusinessException(ErrorCode.DUPLICATE_FAVORITE)
        }

        return RecipeResult.favorite(
            recipeFavoriteRepository.save(
                RecipeFavorite(
                    recipe = recipe,
                    member = member
                )
            )
        )
    }

    fun removeFavorite(command: RecipeCommand.FavoriteRecipe) {
        ensureMember(command.memberId)
        val favorite = recipeFavoriteRepository.findByRecipeAndMember(command.recipeId, command.memberId)
            ?: throw BusinessException(ErrorCode.FAVORITE_NOT_FOUND)
        recipeFavoriteRepository.delete(favorite)
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

    private fun summarizeWithReviewTags(recipes: List<SauceRecipe>): List<RecipeResult.RecipeSummary> {
        val reviewTagsByRecipeId = loadReviewTagCounts(recipes.map { it.id })
        return recipes.map { recipe ->
            RecipeResult.summary(
                recipe,
                reviewTagsByRecipeId[recipe.id].orEmpty(),
                imageUrl = recipeImageUrlResolver.imageUrl(recipe)
            )
        }
    }

    private fun loadReviewTagCounts(recipeIds: Collection<Long>): Map<Long, List<RecipeResult.ReviewTagCount>> {
        if (recipeIds.isEmpty()) {
            return emptyMap()
        }
        return recipeReviewRepository.countTasteTagsByRecipeIds(recipeIds.toSet())
            .groupBy { it.recipeId }
            .mapValues { (_, counts) ->
                counts
                    .map(RecipeResult::reviewTagCount)
                    .sortedWith(
                        compareByDescending<RecipeResult.ReviewTagCount> { it.count }
                            .thenBy { it.name }
                    )
            }
    }
}
