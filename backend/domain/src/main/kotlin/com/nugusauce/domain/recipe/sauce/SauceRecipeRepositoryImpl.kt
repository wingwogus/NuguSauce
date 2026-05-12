package com.nugusauce.domain.recipe.sauce

import com.nugusauce.domain.recipe.ingredient.QRecipeIngredient
import com.nugusauce.domain.recipe.sauce.QSauceRecipe.sauceRecipe
import com.querydsl.core.BooleanBuilder
import com.querydsl.core.types.OrderSpecifier
import com.querydsl.core.types.dsl.BooleanExpression
import com.querydsl.core.types.dsl.DateTimeTemplate
import com.querydsl.core.types.dsl.Expressions
import com.querydsl.core.types.dsl.NumberExpression
import com.querydsl.jpa.JPAExpressions
import com.querydsl.jpa.impl.JPAQueryFactory
import jakarta.persistence.EntityManager
import java.time.Instant

class SauceRecipeRepositoryImpl(
    entityManager: EntityManager
) : SauceRecipeQueryRepository {
    private val queryFactory = JPAQueryFactory(entityManager)

    override fun searchRecipePage(condition: SauceRecipePageCondition): SauceRecipePageSlice {
        require(condition.limit > 0) { "recipe page limit must be positive" }
        require(condition.offset >= 0) { "recipe page offset must not be negative" }

        val fetchedIds = searchRecipeIds(condition, includeHasNextProbe = true)
        val hasNext = fetchedIds.size > condition.limit
        val pageIds = fetchedIds.take(condition.limit)
        if (pageIds.isEmpty()) {
            return SauceRecipePageSlice(recipes = emptyList(), hasNext = false)
        }

        val recipesById = fetchRecipesByIds(pageIds)
        return SauceRecipePageSlice(
            recipes = pageIds.mapNotNull(recipesById::get),
            hasNext = hasNext
        )
    }

    override fun searchHomeSections(condition: SauceRecipeHomeCondition): SauceRecipeHomeSections {
        require(condition.popularLimit > 0) { "home popular limit must be positive" }
        require(condition.recentLimit > 0) { "home recent limit must be positive" }

        val popularIds = searchRecipeIds(
            SauceRecipePageCondition(
                sort = SauceRecipeSort.POPULAR,
                limit = condition.popularLimit
            ),
            includeHasNextProbe = false
        )
        val recentIds = searchRecipeIds(
            SauceRecipePageCondition(
                sort = SauceRecipeSort.RECENT,
                limit = condition.recentLimit
            ),
            includeHasNextProbe = false
        )

        val recipesById = fetchRecipesByIds((popularIds + recentIds).distinct())
        return SauceRecipeHomeSections(
            popular = popularIds.mapNotNull(recipesById::get),
            recent = recentIds.mapNotNull(recipesById::get)
        )
    }

    private fun searchRecipeIds(
        condition: SauceRecipePageCondition,
        includeHasNextProbe: Boolean
    ): List<Long> {
        val popularity = popularityScore()
        val reviewedAt = reviewedOrCreatedAt()
        val query = queryFactory
            .select(sauceRecipe.id)
            .from(sauceRecipe)
            .where(searchPredicate(condition))

        return query
            .orderBy(*orderSpecifiers(condition.sort, popularity, reviewedAt))
            .offset(condition.offset)
            .limit(fetchLimit(condition, includeHasNextProbe))
            .fetch()
    }

    private fun fetchRecipesByIds(recipeIds: List<Long>): Map<Long, SauceRecipe> {
        return queryFactory
            .selectFrom(sauceRecipe)
            .distinct()
            .leftJoin(sauceRecipe.tags).fetchJoin()
            .leftJoin(sauceRecipe.imageAsset).fetchJoin()
            .where(sauceRecipe.id.`in`(recipeIds))
            .fetch()
            .associateBy { it.id }
    }

    private fun searchPredicate(condition: SauceRecipePageCondition): BooleanBuilder {
        val predicate = BooleanBuilder(sauceRecipe.visibility.eq(RecipeVisibility.VISIBLE))
        keywordPredicate(condition.keyword)?.let(predicate::and)
        recipeTagPredicate(condition.tagIds)?.let(predicate::and)
        ingredientPredicate(condition.ingredientIds)?.let(predicate::and)
        return predicate
    }

    private fun keywordPredicate(keyword: String?): BooleanExpression? {
        val normalized = keyword?.trim()?.lowercase()?.takeIf { it.isNotBlank() } ?: return null
        return sauceRecipe.title.lower().contains(normalized)
            .or(sauceRecipe.description.lower().contains(normalized))
            .or(sauceRecipe.tips.lower().contains(normalized))
    }

    private fun recipeTagPredicate(tagIds: Set<Long>): BooleanExpression? {
        if (tagIds.isEmpty()) {
            return null
        }

        return sauceRecipe.tags.any().id.`in`(tagIds)
    }

    private fun ingredientPredicate(ingredientIds: Set<Long>): BooleanExpression? {
        if (ingredientIds.isEmpty()) {
            return null
        }

        val recipeIngredient = QRecipeIngredient("recipeIngredientForSearch")
        return JPAExpressions
            .selectOne()
            .from(recipeIngredient)
            .where(
                recipeIngredient.recipe.id.eq(sauceRecipe.id)
                    .and(recipeIngredient.ingredient.id.`in`(ingredientIds))
            )
            .exists()
    }

    private fun orderSpecifiers(
        sort: SauceRecipeSort,
        popularity: NumberExpression<Double>,
        reviewedAt: DateTimeTemplate<Instant>
    ): Array<OrderSpecifier<*>> {
        return when (sort) {
            SauceRecipeSort.POPULAR -> arrayOf(
                popularity.desc(),
                sauceRecipe.averageRating.desc(),
                reviewedAt.desc(),
                sauceRecipe.id.asc()
            )
            SauceRecipeSort.RECENT -> arrayOf(
                sauceRecipe.createdAt.desc(),
                sauceRecipe.id.asc()
            )
        }
    }

    private fun popularityScore(): NumberExpression<Double> {
        return Expressions.numberTemplate(
            Double::class.javaObjectType,
            "({0} * 2 + {1})",
            sauceRecipe.reviewCount,
            sauceRecipe.favoriteCount
        )
    }

    private fun reviewedOrCreatedAt(): DateTimeTemplate<Instant> {
        return Expressions.dateTimeTemplate(
            Instant::class.java,
            "coalesce({0}, {1})",
            sauceRecipe.lastReviewedAt,
            sauceRecipe.createdAt
        )
    }

    private fun fetchLimit(
        condition: SauceRecipePageCondition,
        includeHasNextProbe: Boolean
    ): Long {
        return condition.limit.toLong() + if (includeHasNextProbe) 1L else 0L
    }
}
