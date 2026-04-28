package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.ingredient.IngredientRepository
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import com.nugusauce.domain.recipe.tag.RecipeTagRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional(readOnly = true)
class RecipeQueryService(
    private val sauceRecipeRepository: SauceRecipeRepository,
    private val ingredientRepository: IngredientRepository,
    private val recipeTagRepository: RecipeTagRepository,
    private val recipeReviewRepository: RecipeReviewRepository,
    private val recipeFavoriteRepository: RecipeFavoriteRepository,
    private val recipeImageUrlResolver: RecipeImageUrlResolver
) {
    fun search(command: RecipeCommand.SearchRecipes): List<RecipeResult.RecipeSummary> {
        val keyword = command.q?.trim()?.takeIf { it.isNotBlank() }?.lowercase()
        return sauceRecipeRepository.findAllByVisibility(RecipeVisibility.VISIBLE)
            .let { recipes ->
                val reviewTagsByRecipeId = loadReviewTagCounts(recipes.map { it.id })
                recipes
                    .asSequence()
                    .filter { recipe -> keyword == null || recipe.matchesKeyword(keyword) }
                    .filter { recipe ->
                        command.tagIds.isEmpty() ||
                            reviewTagsByRecipeId[recipe.id].orEmpty().any { it.id in command.tagIds }
                    }
                    .filter { recipe ->
                        command.ingredientIds.isEmpty() ||
                            recipe.ingredients.any { it.ingredient.id in command.ingredientIds }
                    }
                    .toList()
                    .sortedWith(command.sort.comparator())
                    .map { recipe ->
                        RecipeResult.summary(
                            recipe,
                            reviewTagsByRecipeId[recipe.id].orEmpty(),
                            imageUrl = recipeImageUrlResolver.imageUrl(recipe)
                        )
                    }
            }
    }

    fun getDetail(recipeId: Long, memberId: Long? = null): RecipeResult.RecipeDetail {
        val recipe = findVisibleRecipe(recipeId)
        return RecipeResult.detail(
            recipe,
            loadReviewTagCounts(listOf(recipe.id))[recipe.id].orEmpty(),
            isFavorite = memberId?.let {
                recipeFavoriteRepository.existsByRecipeAndMember(recipe.id, it)
            } ?: false,
            imageUrl = recipeImageUrlResolver.imageUrl(recipe)
        )
    }

    fun listIngredients(): List<RecipeResult.IngredientItem> {
        return ingredientRepository.findAllByOrderByNameAsc()
            .map(RecipeResult::fromIngredient)
    }

    fun listTags(): List<RecipeResult.TagItem> {
        return recipeTagRepository.findAllByOrderByNameAsc()
            .map(RecipeResult::fromTag)
    }

    fun listReviews(recipeId: Long): List<RecipeResult.ReviewItem> {
        findVisibleRecipe(recipeId)
        return recipeReviewRepository.findAllByRecipeIdOrderByCreatedAtDesc(recipeId)
            .map(RecipeResult::review)
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

    private fun SauceRecipe.matchesKeyword(keyword: String): Boolean {
        return title.lowercase().contains(keyword) ||
            description.lowercase().contains(keyword) ||
            (tips?.lowercase()?.contains(keyword) ?: false)
    }

    private fun RecipeCommand.RecipeSort.comparator(): Comparator<SauceRecipe> {
        return when (this) {
            RecipeCommand.RecipeSort.POPULAR ->
                compareByDescending<SauceRecipe> { it.reviewCount }
                    .thenByDescending { it.averageRating }
                    .thenByDescending { it.lastReviewedAt ?: it.createdAt }
            RecipeCommand.RecipeSort.RECENT ->
                compareByDescending { it.createdAt }
            RecipeCommand.RecipeSort.RATING ->
                compareByDescending<SauceRecipe> { it.averageRating }
                    .thenByDescending { it.reviewCount }
                    .thenByDescending { it.lastReviewedAt ?: it.createdAt }
        }
    }
}
