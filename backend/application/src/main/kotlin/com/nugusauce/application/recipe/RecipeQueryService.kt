package com.nugusauce.application.recipe

import com.nugusauce.application.common.cursor.CursorCodec
import com.nugusauce.application.common.cursor.CursorShape
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.ingredient.IngredientRepository
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeHomeCondition
import com.nugusauce.domain.recipe.sauce.SauceRecipePageCondition
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import com.nugusauce.domain.recipe.sauce.SauceRecipeSort
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
    private val imageUrlResolver: ImageUrlResolver,
    private val tagDerivationPolicy: RecipeTagDerivationPolicy
) {
    private val cursorCodec = CursorCodec()

    fun search(command: RecipeCommand.SearchRecipes): RecipeResult.RecipeSearchPage {
        val normalizedQuery = command.normalizedQuery()
        val normalizedLimit = normalizeLimit(command.limit)
        val normalizedTagIds = command.tagIds.distinct().sorted()
        val normalizedIngredientIds = command.ingredientIds.distinct().sorted()
        val sort = command.sort
        val cursorShape = CursorShape(
            mapOf(
                "q" to normalizedQuery,
                "tagIds" to normalizedTagIds.joinToString(","),
                "ingredientIds" to normalizedIngredientIds.joinToString(","),
                "sort" to sort.name.lowercase(),
                "limit" to normalizedLimit.toString()
            )
        )
        val decodedCursor = cursorCodec.decode(command.cursor, cursorShape)
        val domainSort = sort.toDomainSort()
        val offset = decodedCursor?.offset ?: 0L

        val slice = sauceRecipeRepository.searchRecipePage(
            SauceRecipePageCondition(
                keyword = normalizedQuery,
                tagIds = normalizedTagIds.toSet(),
                ingredientIds = normalizedIngredientIds.toSet(),
                sort = domainSort,
                limit = normalizedLimit,
                offset = offset
            )
        )
        val favoriteRecipeIds = loadFavoriteRecipeIds(
            command.viewerMemberId,
            slice.recipes.map { it.id }
        )
        val items = summarizeRecipes(slice.recipes, favoriteRecipeIds)
        val nextCursor = if (slice.hasNext && slice.recipes.isNotEmpty()) {
            cursorCodec.encode(cursorShape, offset + slice.recipes.size)
        } else {
            null
        }

        return RecipeResult.RecipeSearchPage(
            items = items,
            nextCursor = nextCursor,
            hasNext = slice.hasNext
        )
    }

    fun home(command: RecipeCommand.HomeFeed): RecipeResult.HomeFeed {
        val sections = sauceRecipeRepository.searchHomeSections(
            SauceRecipeHomeCondition(
                popularLimit = HOME_POPULAR_LIMIT,
                recentLimit = HOME_RECENT_LIMIT
            )
        )

        val favoriteRecipeIds = loadFavoriteRecipeIds(
            command.viewerMemberId,
            (sections.popular + sections.recent).map { it.id }.toSet()
        )

        return RecipeResult.HomeFeed(
            popularTop = summarizeRecipes(sections.popular, favoriteRecipeIds),
            recentTop = summarizeRecipes(sections.recent, favoriteRecipeIds)
        )
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

    private fun summarizeRecipes(
        recipes: List<SauceRecipe>,
        favoriteRecipeIds: Set<Long>
    ): List<RecipeResult.RecipeSummary> {
        return recipes.map { recipe ->
            RecipeResult.summary(
                recipe,
                isFavorite = recipe.id in favoriteRecipeIds,
                imageUrl = imageUrlResolver.recipeImageUrl(recipe)
            )
        }
    }

    private fun RecipeCommand.SearchRecipes.normalizedQuery(): String? {
        return q?.trim()?.takeIf { it.isNotBlank() }
    }

    private fun normalizeLimit(limit: Int?): Int {
        return (limit ?: DEFAULT_SEARCH_LIMIT).coerceIn(MIN_SEARCH_LIMIT, MAX_SEARCH_LIMIT)
    }

    private fun RecipeCommand.RecipeSort.toDomainSort(): SauceRecipeSort {
        return when (this) {
            RecipeCommand.RecipeSort.POPULAR -> SauceRecipeSort.POPULAR
            RecipeCommand.RecipeSort.RECENT -> SauceRecipeSort.RECENT
        }
    }

    private companion object {
        const val DEFAULT_SEARCH_LIMIT = 20
        const val MIN_SEARCH_LIMIT = 1
        const val MAX_SEARCH_LIMIT = 50
        const val HOME_POPULAR_LIMIT = 5
        const val HOME_RECENT_LIMIT = 10
    }
}
