package com.nugusauce.domain.recipe.sauce

import com.nugusauce.domain.recipe.favorite.QRecipeFavorite
import com.nugusauce.domain.recipe.ingredient.QRecipeIngredient
import com.nugusauce.domain.recipe.review.QRecipeReview
import com.nugusauce.domain.recipe.sauce.QSauceRecipe.sauceRecipe
import com.querydsl.core.BooleanBuilder
import com.querydsl.core.types.OrderSpecifier
import com.querydsl.core.types.dsl.BooleanExpression
import com.querydsl.core.types.dsl.CaseBuilder
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

    override fun searchVisibleRecipes(condition: SauceRecipeSearchCondition): List<SauceRecipe> {
        val recipeIds = when (condition.sort) {
            SauceRecipeSort.HOT -> searchHotVisibleRecipeIds(condition)
            SauceRecipeSort.POPULAR,
            SauceRecipeSort.RECENT,
            SauceRecipeSort.RATING -> searchVisibleRecipeIds(condition)
        }
        if (recipeIds.isEmpty()) {
            return emptyList()
        }

        val recipesById = queryFactory
            .selectFrom(sauceRecipe)
            .distinct()
            .leftJoin(sauceRecipe.tags).fetchJoin()
            .where(sauceRecipe.id.`in`(recipeIds))
            .fetch()
            .associateBy { it.id }

        return recipeIds.mapNotNull(recipesById::get)
    }

    private fun searchVisibleRecipeIds(condition: SauceRecipeSearchCondition): List<Long> {
        return queryFactory
            .select(sauceRecipe.id)
            .from(sauceRecipe)
            .where(searchPredicate(condition))
            .orderBy(*orderSpecifiers(condition.sort))
            .fetch()
    }

    private fun searchHotVisibleRecipeIds(condition: SauceRecipeSearchCondition): List<Long> {
        val recentReview = QRecipeReview("recentReview")
        val recentFavorite = QRecipeFavorite("recentFavorite")
        val recentReviewCount = recentReview.id.countDistinct()
        val recentFavoriteCount = recentFavorite.id.countDistinct()
        val hasRecentActivity = CaseBuilder()
            .`when`(recentReviewCount.gt(0).or(recentFavoriteCount.gt(0)))
            .then(1)
            .otherwise(0)
        val hotScore = Expressions.numberTemplate(
            Double::class.javaObjectType,
            "({0} * 4 + {1} * 2 + {2} * least({3}, 20) * 0.15)",
            recentReviewCount,
            recentFavoriteCount,
            sauceRecipe.averageRating,
            sauceRecipe.reviewCount
        )

        return queryFactory
            .select(sauceRecipe.id)
            .from(sauceRecipe)
            .leftJoin(recentReview).on(
                recentReview.recipe.id.eq(sauceRecipe.id)
                    .and(recentReview.createdAt.goe(condition.hotSince ?: Instant.EPOCH))
            )
            .leftJoin(recentFavorite).on(
                recentFavorite.recipe.id.eq(sauceRecipe.id)
                    .and(recentFavorite.createdAt.goe(condition.hotSince ?: Instant.EPOCH))
            )
            .where(searchPredicate(condition))
            .groupBy(
                sauceRecipe.id,
                sauceRecipe.reviewCount,
                sauceRecipe.favoriteCount,
                sauceRecipe.averageRating,
                sauceRecipe.lastReviewedAt,
                sauceRecipe.createdAt
            )
            .orderBy(
                hasRecentActivity.desc(),
                hotScore.desc(),
                popularityScore().desc(),
                sauceRecipe.averageRating.desc(),
                reviewedOrCreatedAt().desc(),
                sauceRecipe.id.asc()
            )
            .fetch()
    }

    private fun searchPredicate(condition: SauceRecipeSearchCondition): BooleanBuilder {
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

    private fun orderSpecifiers(sort: SauceRecipeSort): Array<OrderSpecifier<*>> {
        return when (sort) {
            SauceRecipeSort.POPULAR -> arrayOf(
                popularityScore().desc(),
                sauceRecipe.averageRating.desc(),
                reviewedOrCreatedAt().desc(),
                sauceRecipe.id.asc()
            )
            SauceRecipeSort.HOT -> arrayOf(
                popularityScore().desc(),
                sauceRecipe.averageRating.desc(),
                reviewedOrCreatedAt().desc(),
                sauceRecipe.id.asc()
            )
            SauceRecipeSort.RECENT -> arrayOf(
                sauceRecipe.createdAt.desc(),
                sauceRecipe.id.asc()
            )
            SauceRecipeSort.RATING -> arrayOf(
                sauceRecipe.averageRating.desc(),
                sauceRecipe.reviewCount.desc(),
                reviewedOrCreatedAt().desc(),
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
}
