package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.ingredient.IngredientRepository
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import com.nugusauce.domain.recipe.sauce.SauceRecipeSearchCondition
import com.nugusauce.domain.recipe.sauce.SauceRecipeSort
import com.nugusauce.domain.recipe.tag.RecipeTagRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.temporal.ChronoUnit

@Service
@Transactional(readOnly = true)
class RecipeQueryService(
    private val sauceRecipeRepository: SauceRecipeRepository,
    private val ingredientRepository: IngredientRepository,
    private val recipeTagRepository: RecipeTagRepository,
    private val recipeReviewRepository: RecipeReviewRepository,
    private val recipeFavoriteRepository: RecipeFavoriteRepository,
    private val imageUrlResolver: ImageUrlResolver,
    private val tagDerivationPolicy: RecipeTagDerivationPolicy,
    private val clock: Clock = Clock.systemUTC()
) {
    fun search(command: RecipeCommand.SearchRecipes): List<RecipeResult.RecipeSummary> {
        val recipes = sauceRecipeRepository.searchVisibleRecipes(command.toSearchCondition())
        val favoriteRecipeIds = loadFavoriteRecipeIds(command.viewerMemberId, recipes.map { it.id })
        return recipes
            .map { recipe ->
                RecipeResult.summary(
                    recipe,
                    isFavorite = recipe.id in favoriteRecipeIds,
                    imageUrl = imageUrlResolver.recipeImageUrl(recipe)
                )
            }
    }

    fun getDetail(recipeId: Long, memberId: Long? = null): RecipeResult.RecipeDetail {
        val recipe = findVisibleRecipe(recipeId)
        return RecipeResult.detail(
            recipe,
            isFavorite = memberId?.let {
                recipeFavoriteRepository.existsByRecipeAndMember(recipe.id, it)
            } ?: false,
            imageUrl = imageUrlResolver.recipeImageUrl(recipe),
            authorProfileImageUrl = recipe.author?.let(imageUrlResolver::memberProfileImageUrl)
        )
    }

    fun listIngredients(): List<RecipeResult.IngredientItem> {
        return ingredientRepository.findAllByOrderByNameAsc()
            .map(RecipeResult::fromIngredient)
    }

    fun listTags(): List<RecipeResult.TagItem> {
        val tagsByName = recipeTagRepository.findAllByNameIn(tagDerivationPolicy.canonicalTagNames)
            .associateBy { it.name }
        return tagDerivationPolicy.canonicalTagNames
            .mapNotNull(tagsByName::get)
            .map(RecipeResult::fromTag)
    }

    fun listReviews(recipeId: Long): List<RecipeResult.ReviewItem> {
        findVisibleRecipe(recipeId)
        return recipeReviewRepository.findAllByRecipeIdOrderByCreatedAtDesc(recipeId)
            .map { review ->
                RecipeResult.review(
                    review,
                    authorProfileImageUrl = imageUrlResolver.memberProfileImageUrl(review.author)
                )
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

    private fun loadFavoriteRecipeIds(memberId: Long?, recipeIds: Collection<Long>): Set<Long> {
        if (memberId == null || recipeIds.isEmpty()) {
            return emptySet()
        }
        return recipeFavoriteRepository.findRecipeIdsByMemberAndRecipeIds(memberId, recipeIds.toSet())
    }

    private fun RecipeCommand.SearchRecipes.toSearchCondition(): SauceRecipeSearchCondition {
        val domainSort = sort.toDomainSort()
        return SauceRecipeSearchCondition(
            keyword = q?.trim()?.takeIf { it.isNotBlank() },
            tagIds = tagIds.toSet(),
            ingredientIds = ingredientIds.toSet(),
            sort = domainSort,
            hotSince = if (domainSort == SauceRecipeSort.HOT) {
                clock.instant().minus(7, ChronoUnit.DAYS)
            } else {
                null
            }
        )
    }

    private fun RecipeCommand.RecipeSort.toDomainSort(): SauceRecipeSort {
        return when (this) {
            RecipeCommand.RecipeSort.HOT -> SauceRecipeSort.HOT
            RecipeCommand.RecipeSort.POPULAR -> SauceRecipeSort.POPULAR
            RecipeCommand.RecipeSort.RECENT -> SauceRecipeSort.RECENT
            RecipeCommand.RecipeSort.RATING -> SauceRecipeSort.RATING
        }
    }
}
