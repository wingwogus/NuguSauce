package com.nugusauce.domain.recipe.sauce

import com.nugusauce.domain.member.Member
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.recipe.favorite.RecipeFavorite
import com.nugusauce.domain.recipe.ingredient.Ingredient
import com.nugusauce.domain.recipe.review.RecipeReview
import com.nugusauce.domain.recipe.tag.RecipeTag
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.SpringBootConfiguration
import org.springframework.boot.autoconfigure.EnableAutoConfiguration
import org.springframework.boot.autoconfigure.domain.EntityScan
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager
import org.springframework.context.annotation.Import
import org.springframework.data.jpa.repository.config.EnableJpaRepositories
import org.springframework.test.context.ContextConfiguration
import java.math.BigDecimal
import java.time.Instant
import java.time.temporal.ChronoUnit

@DataJpaTest
@ContextConfiguration(classes = [SauceRecipeRepositoryImplTest.JpaTestApplication::class])
class SauceRecipeRepositoryImplTest @Autowired constructor(
    private val sauceRecipeRepository: SauceRecipeRepository,
    private val entityManager: TestEntityManager
) {
    @Test
    fun `searchVisibleRecipes filters keyword review tag ingredient and visibility in query`() {
        val garlic = ingredient("마늘")
        val honey = ingredient("꿀")
        val spicy = tag("매콤함")
        val creamy = tag("고소함")
        val target = recipe(title = "마라 디핑", ingredients = listOf(garlic))
        review(target, spicy)
        val wrongIngredient = recipe(title = "마라 허니", ingredients = listOf(honey))
        review(wrongIngredient, spicy)
        val wrongTag = recipe(title = "마라 갈릭", ingredients = listOf(garlic))
        review(wrongTag, creamy)
        val hidden = recipe(
            title = "마라 히든",
            ingredients = listOf(garlic),
            visibility = RecipeVisibility.HIDDEN
        )
        review(hidden, spicy)
        flushAndClear()

        val results = sauceRecipeRepository.searchVisibleRecipes(
            SauceRecipeSearchCondition(
                keyword = "마라",
                tagIds = setOf(spicy.id),
                ingredientIds = setOf(garlic.id)
            )
        )

        assertEquals(listOf(target.id), results.map { it.id })
    }

    @Test
    fun `searchVisibleRecipes hot sort ranks recent engagement above older popularity`() {
        val since = Instant.parse("2026-04-22T00:00:00Z")
        val spicy = tag("매콤함")
        val olderPopular = recipe(
            title = "누적 인기 소스",
            reviewCount = 80,
            averageRating = 4.9,
            lastReviewedAt = since.minus(10, ChronoUnit.DAYS)
        )
        val hotRecipe = recipe(
            title = "요즘 핫한 소스",
            reviewCount = 2,
            averageRating = 4.0,
            lastReviewedAt = since.plus(1, ChronoUnit.DAYS)
        )
        review(hotRecipe, spicy, createdAt = since.plus(1, ChronoUnit.DAYS))
        flushAndClear()

        val results = sauceRecipeRepository.searchVisibleRecipes(
            SauceRecipeSearchCondition(
                sort = SauceRecipeSort.HOT,
                hotSince = since
            )
        )

        assertEquals(listOf(hotRecipe.id, olderPopular.id), results.map { it.id })
    }

    @Test
    fun `searchVisibleRecipes hot sort falls back to popular order without recent engagement`() {
        val since = Instant.parse("2026-04-22T00:00:00Z")
        val lessReviewed = recipe(title = "적은 리뷰", reviewCount = 3, averageRating = 5.0)
        val moreReviewed = recipe(title = "많은 리뷰", reviewCount = 20, averageRating = 4.0)
        flushAndClear()

        val results = sauceRecipeRepository.searchVisibleRecipes(
            SauceRecipeSearchCondition(
                sort = SauceRecipeSort.HOT,
                hotSince = since
            )
        )

        assertEquals(listOf(moreReviewed.id, lessReviewed.id), results.map { it.id })
    }

    @Test
    fun `searchVisibleRecipes hot sort uses recent favorites as engagement`() {
        val since = Instant.parse("2026-04-22T00:00:00Z")
        val noRecentActivity = recipe(title = "오래된 고평점 소스", reviewCount = 30, averageRating = 5.0)
        val recentlyFavorited = recipe(title = "찜이 붙는 소스", reviewCount = 1, averageRating = 3.5)
        favorite(recentlyFavorited, createdAt = since.plus(2, ChronoUnit.DAYS))
        flushAndClear()

        val results = sauceRecipeRepository.searchVisibleRecipes(
            SauceRecipeSearchCondition(
                sort = SauceRecipeSort.HOT,
                hotSince = since
            )
        )

        assertEquals(listOf(recentlyFavorited.id, noRecentActivity.id), results.map { it.id })
    }

    @Test
    fun `searchVisibleRecipes orders popular recent and rating sorts in query`() {
        recipe(
            title = "많은 리뷰",
            reviewCount = 10,
            averageRating = 4.0,
            createdAt = Instant.parse("2026-04-01T00:00:00Z")
        )
        recipe(
            title = "높은 평점",
            reviewCount = 3,
            averageRating = 5.0,
            createdAt = Instant.parse("2026-04-02T00:00:00Z")
        )
        recipe(
            title = "최신 소스",
            reviewCount = 1,
            averageRating = 3.0,
            createdAt = Instant.parse("2026-04-03T00:00:00Z")
        )
        flushAndClear()

        val popular = sauceRecipeRepository.searchVisibleRecipes(
            SauceRecipeSearchCondition(sort = SauceRecipeSort.POPULAR)
        )
        val recent = sauceRecipeRepository.searchVisibleRecipes(
            SauceRecipeSearchCondition(sort = SauceRecipeSort.RECENT)
        )
        val rating = sauceRecipeRepository.searchVisibleRecipes(
            SauceRecipeSearchCondition(sort = SauceRecipeSort.RATING)
        )

        assertEquals(listOf("많은 리뷰", "높은 평점", "최신 소스"), popular.map { it.title })
        assertEquals(listOf("최신 소스", "높은 평점", "많은 리뷰"), recent.map { it.title })
        assertEquals(listOf("높은 평점", "많은 리뷰", "최신 소스"), rating.map { it.title })
    }

    private fun recipe(
        title: String,
        ingredients: List<Ingredient> = emptyList(),
        visibility: RecipeVisibility = RecipeVisibility.VISIBLE,
        reviewCount: Int = 0,
        averageRating: Double = 0.0,
        lastReviewedAt: Instant? = null,
        createdAt: Instant = Instant.parse("2026-04-01T00:00:00Z")
    ): SauceRecipe {
        return SauceRecipe(
            title = title,
            description = "$title 설명",
            spiceLevel = 3,
            richnessLevel = 4,
            authorType = RecipeAuthorType.CURATED,
            visibility = visibility,
            createdAt = createdAt,
            lastReviewedAt = lastReviewedAt
        ).apply {
            this.reviewCount = reviewCount
            this.averageRating = averageRating
            ingredients.forEach { ingredient ->
                addIngredient(ingredient, BigDecimal.ONE, "g", null)
            }
        }.let(entityManager::persistAndFlush)
    }

    private fun ingredient(name: String): Ingredient {
        return entityManager.persistAndFlush(Ingredient(name = name))
    }

    private fun tag(name: String): RecipeTag {
        return entityManager.persistAndFlush(RecipeTag(name = name))
    }

    private fun review(
        recipe: SauceRecipe,
        tag: RecipeTag,
        createdAt: Instant = Instant.parse("2026-04-01T00:00:00Z")
    ): RecipeReview {
        return RecipeReview(
            recipe = recipe,
            author = member("reviewer-${recipe.id}-${tag.id}@example.test"),
            rating = 5,
            createdAt = createdAt
        ).apply {
            tasteTags.add(tag)
        }.let(entityManager::persistAndFlush)
    }

    private fun favorite(
        recipe: SauceRecipe,
        createdAt: Instant = Instant.parse("2026-04-01T00:00:00Z")
    ): RecipeFavorite {
        return entityManager.persistAndFlush(
            RecipeFavorite(
                recipe = recipe,
                member = member("favorite-${recipe.id}@example.test"),
                createdAt = createdAt
            )
        )
    }

    private fun member(email: String): Member {
        return entityManager.persistAndFlush(Member(email = email, passwordHash = null))
    }

    private fun flushAndClear() {
        entityManager.flush()
        entityManager.clear()
    }

    @SpringBootConfiguration
    @EnableAutoConfiguration
    @EntityScan(
        basePackageClasses = [
            Member::class,
            MediaAsset::class,
            SauceRecipe::class,
            Ingredient::class,
            RecipeTag::class,
            RecipeReview::class,
            RecipeFavorite::class
        ]
    )
    @EnableJpaRepositories(basePackageClasses = [SauceRecipeRepository::class])
    @Import(SauceRecipeRepositoryImpl::class)
    class JpaTestApplication
}
