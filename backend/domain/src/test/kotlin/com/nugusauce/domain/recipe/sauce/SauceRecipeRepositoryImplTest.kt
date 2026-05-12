package com.nugusauce.domain.recipe.sauce

import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.recipe.favorite.RecipeFavorite
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.ingredient.Ingredient
import com.nugusauce.domain.recipe.ingredient.RecipeIngredient
import com.nugusauce.domain.recipe.report.RecipeReport
import com.nugusauce.domain.recipe.report.RecipeReportRepository
import com.nugusauce.domain.recipe.review.RecipeReview
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
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
import org.springframework.test.annotation.DirtiesContext
import org.springframework.test.context.ContextConfiguration
import org.springframework.transaction.PlatformTransactionManager
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import org.springframework.transaction.support.TransactionTemplate
import java.math.BigDecimal
import java.time.Instant
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@DataJpaTest
@ContextConfiguration(classes = [SauceRecipeRepositoryImplTest.JpaTestApplication::class])
class SauceRecipeRepositoryImplTest @Autowired constructor(
    private val sauceRecipeRepository: SauceRecipeRepository,
    private val recipeFavoriteRepository: RecipeFavoriteRepository,
    private val recipeReviewRepository: RecipeReviewRepository,
    private val recipeReportRepository: RecipeReportRepository,
    private val memberRepository: MemberRepository,
    private val transactionManager: PlatformTransactionManager,
    private val entityManager: TestEntityManager
) {
    @Test
    fun `searchRecipePage filters keyword recipe tag ingredient and visibility in query`() {
        val garlic = ingredient("마늘")
        val honey = ingredient("꿀")
        val spicy = tag("매콤함")
        val creamy = tag("고소함")
        val target = recipe(title = "마라 디핑", ingredients = listOf(garlic)).apply {
            replaceDerivedTags(listOf(spicy))
        }
        recipe(title = "마라 허니", ingredients = listOf(honey)).apply {
            replaceDerivedTags(listOf(spicy))
        }
        recipe(title = "마라 갈릭", ingredients = listOf(garlic)).apply {
            replaceDerivedTags(listOf(creamy))
        }
        recipe(
            title = "마라 히든",
            ingredients = listOf(garlic),
            visibility = RecipeVisibility.HIDDEN
        ).apply {
            replaceDerivedTags(listOf(spicy))
        }
        flushAndClear()

        val results = sauceRecipeRepository.searchRecipePage(
            SauceRecipePageCondition(
                keyword = "마라",
                tagIds = setOf(spicy.id),
                ingredientIds = setOf(garlic.id),
                limit = 20
            )
        )

        assertEquals(listOf(target.id), results.recipes.map { it.id })
    }

    @Test
    fun `searchRecipePage popular sort uses review and favorite engagement score`() {
        recipe(title = "리뷰만 많은 소스", reviewCount = 5, favoriteCount = 0, averageRating = 4.9)
        recipe(title = "찜이 많은 소스", reviewCount = 2, favoriteCount = 8, averageRating = 4.0)
        recipe(title = "낮은 참여 소스", reviewCount = 3, favoriteCount = 1, averageRating = 5.0)
        flushAndClear()

        val results = sauceRecipeRepository.searchRecipePage(
            SauceRecipePageCondition(sort = SauceRecipeSort.POPULAR, limit = 20)
        )

        assertEquals(listOf("찜이 많은 소스", "리뷰만 많은 소스", "낮은 참여 소스"), results.recipes.map { it.title })
    }

    @Test
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    @DirtiesContext(methodMode = DirtiesContext.MethodMode.AFTER_METHOD)
    fun `favorite count stays aligned with rows after parallel favorites`() {
        val transactionTemplate = TransactionTemplate(transactionManager)
        val favoriteSize = 8
        val (recipeId, memberIds) = transactionTemplate.execute {
            val recipe = recipe(title = "동시 찜 소스")
            val members = (1..favoriteSize).map { index ->
                member("parallel-$index@example.test")
            }
            recipe.id to members.map { it.id }
        }!!
        val executor = Executors.newFixedThreadPool(favoriteSize)
        val ready = CountDownLatch(favoriteSize)
        val start = CountDownLatch(1)
        val done = CountDownLatch(favoriteSize)
        val errors = Collections.synchronizedList(mutableListOf<Throwable>())

        memberIds.forEach { memberId ->
            executor.submit {
                try {
                    ready.countDown()
                    start.await()
                    transactionTemplate.executeWithoutResult {
                        recipeFavoriteRepository.save(
                            RecipeFavorite(
                                recipe = sauceRecipeRepository.getReferenceById(recipeId),
                                member = memberRepository.getReferenceById(memberId)
                            )
                        )
                        sauceRecipeRepository.incrementFavoriteCount(recipeId, Instant.now())
                    }
                } catch (error: Throwable) {
                    errors.add(error)
                } finally {
                    done.countDown()
                }
            }
        }

        assertEquals(true, ready.await(5, TimeUnit.SECONDS))
        start.countDown()
        assertEquals(true, done.await(10, TimeUnit.SECONDS))
        executor.shutdown()
        if (errors.isNotEmpty()) {
            throw AssertionError("parallel favorite insert failed", errors.first())
        }

        val persisted = transactionTemplate.execute {
            val recipe = sauceRecipeRepository.findById(recipeId).orElseThrow()
            recipe.favoriteCount to recipeFavoriteRepository.countByRecipeId(recipeId)
        }!!
        assertEquals(favoriteSize, persisted.first)
        assertEquals(favoriteSize.toLong(), persisted.second)
    }

    @Test
    fun `searchRecipePage orders popular and recent sorts in query`() {
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

        val popular = sauceRecipeRepository.searchRecipePage(
            SauceRecipePageCondition(sort = SauceRecipeSort.POPULAR, limit = 20)
        )
        val recent = sauceRecipeRepository.searchRecipePage(
            SauceRecipePageCondition(sort = SauceRecipeSort.RECENT, limit = 20)
        )
        assertEquals(listOf("많은 리뷰", "높은 평점", "최신 소스"), popular.recipes.map { it.title })
        assertEquals(listOf("최신 소스", "높은 평점", "많은 리뷰"), recent.recipes.map { it.title })
    }

    @Test
    fun `searchHomeSections loads ranked sections with shared graph fetch`() {
        val olderPopular = recipe(
            title = "누적 인기 소스",
            reviewCount = 40,
            averageRating = 4.5,
            createdAt = Instant.parse("2026-04-01T00:00:00Z")
        )
        val middle = recipe(title = "중간 소스", reviewCount = 1, createdAt = Instant.parse("2026-04-02T00:00:00Z"))
        val newest = recipe(
            title = "최신 소스",
            reviewCount = 2,
            averageRating = 3.0,
            createdAt = Instant.parse("2026-04-03T00:00:00Z")
        )
        flushAndClear()

        val sections = sauceRecipeRepository.searchHomeSections(
            SauceRecipeHomeCondition(
                popularLimit = 2,
                recentLimit = 2
            )
        )

        assertEquals(olderPopular.id, sections.popular.first().id)
        assertEquals(listOf(newest.id, middle.id), sections.recent.map { it.id })
    }

    @Test
    fun `searchRecipePage recent sort continues after cursor`() {
        val oldest = recipe(title = "가장 오래된 소스", createdAt = Instant.parse("2026-04-01T00:00:00Z"))
        val middle = recipe(title = "중간 소스", createdAt = Instant.parse("2026-04-02T00:00:00Z"))
        val newest = recipe(title = "최신 소스", createdAt = Instant.parse("2026-04-03T00:00:00Z"))
        flushAndClear()

        val firstPage = sauceRecipeRepository.searchRecipePage(
            SauceRecipePageCondition(sort = SauceRecipeSort.RECENT, limit = 2)
        )
        val secondPage = sauceRecipeRepository.searchRecipePage(
            SauceRecipePageCondition(
                sort = SauceRecipeSort.RECENT,
                limit = 2,
                offset = firstPage.recipes.size.toLong()
            )
        )

        assertEquals(true, firstPage.hasNext)
        assertEquals(listOf(newest.id, middle.id), firstPage.recipes.map { it.id })
        assertEquals(false, secondPage.hasNext)
        assertEquals(listOf(oldest.id), secondPage.recipes.map { it.id })
    }

    @Test
    fun `replaceIngredients orphan removes old ingredient rows after flush`() {
        val sesameOil = ingredient("참기름")
        val peanutSauce = ingredient("땅콩소스")
        val recipe = recipe(title = "재료 교체 소스", ingredients = listOf(sesameOil))
        flushAndClear()

        val managedRecipe = sauceRecipeRepository.findById(recipe.id).orElseThrow()
        val managedPeanutSauce = entityManager.find(Ingredient::class.java, peanutSauce.id)
        managedRecipe.replaceIngredients(
            listOf(
                SauceRecipe.IngredientInput(
                    ingredient = managedPeanutSauce,
                    amount = BigDecimal("2.0"),
                    unit = "스푼",
                    ratio = null
                )
            )
        )
        flushAndClear()

        val ingredientNames = entityManager.entityManager
            .createQuery(
                """
                select i.ingredient.name
                from RecipeIngredient i
                where i.recipe.id = :recipeId
                order by i.ingredient.name
                """.trimIndent(),
                String::class.java
            )
            .setParameter("recipeId", recipe.id)
            .resultList

        assertEquals(listOf("땅콩소스"), ingredientNames)
    }

    @Test
    fun `deleting recipe graph removes dependent rows instead of soft hiding`() {
        val sesameOil = ingredient("참기름")
        val savory = tag("고소함")
        val target = recipe(title = "삭제 대상 소스", ingredients = listOf(sesameOil)).apply {
            replaceDerivedTags(listOf(savory))
        }
        review(target)
        favorite(target)
        report(target)
        flushAndClear()

        val managedRecipe = sauceRecipeRepository.findById(target.id).orElseThrow()
        recipeReportRepository.deleteAll(recipeReportRepository.findAllByRecipeId(target.id))
        recipeFavoriteRepository.deleteAll(recipeFavoriteRepository.findAllByRecipeId(target.id))
        recipeReviewRepository.deleteAll(recipeReviewRepository.findAllByRecipeId(target.id))
        sauceRecipeRepository.delete(managedRecipe)
        flushAndClear()

        assertEquals(false, sauceRecipeRepository.findById(target.id).isPresent)
        assertEquals(
            0L,
            countByRecipeId("select count(i) from RecipeIngredient i where i.recipe.id = :recipeId", target.id)
        )
        assertEquals(
            0L,
            countByRecipeId("select count(f) from RecipeFavorite f where f.recipe.id = :recipeId", target.id)
        )
        assertEquals(
            0L,
            countByRecipeId("select count(r) from RecipeReview r where r.recipe.id = :recipeId", target.id)
        )
        assertEquals(
            0L,
            countByRecipeId("select count(r) from RecipeReport r where r.recipe.id = :recipeId", target.id)
        )
        assertEquals(0L, nativeCount("select count(*) from sauce_recipe_tag"))
    }

    private fun recipe(
        title: String,
        ingredients: List<Ingredient> = emptyList(),
        visibility: RecipeVisibility = RecipeVisibility.VISIBLE,
        reviewCount: Int = 0,
        favoriteCount: Int = 0,
        averageRating: Double = 0.0,
        lastReviewedAt: Instant? = null,
        createdAt: Instant = Instant.parse("2026-04-01T00:00:00Z")
    ): SauceRecipe {
        return SauceRecipe(
            title = title,
            description = "$title 설명",
            spiceLevel = 3,
            richnessLevel = 4,
            visibility = visibility,
            createdAt = createdAt,
            lastReviewedAt = lastReviewedAt,
            favoriteCount = favoriteCount
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
        createdAt: Instant = Instant.parse("2026-04-01T00:00:00Z")
    ): RecipeReview {
        return RecipeReview(
            recipe = recipe,
            author = member("reviewer-${recipe.id}-${createdAt.toEpochMilli()}@example.test"),
            rating = 5,
            createdAt = createdAt
        ).let(entityManager::persistAndFlush)
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

    private fun report(
        recipe: SauceRecipe,
        createdAt: Instant = Instant.parse("2026-04-01T00:00:00Z")
    ): RecipeReport {
        return entityManager.persistAndFlush(
            RecipeReport(
                recipe = recipe,
                reporter = member("reporter-${recipe.id}@example.test"),
                reason = "부적절한 내용",
                createdAt = createdAt
            )
        )
    }

    private fun member(email: String): Member {
        return entityManager.persistAndFlush(Member(email = email, passwordHash = null))
    }

    private fun countByRecipeId(jpql: String, recipeId: Long): Long {
        return entityManager.entityManager
            .createQuery(jpql, Long::class.javaObjectType)
            .setParameter("recipeId", recipeId)
            .singleResult
            .toLong()
    }

    private fun nativeCount(sql: String): Long {
        return (entityManager.entityManager.createNativeQuery(sql).singleResult as Number).toLong()
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
            RecipeIngredient::class,
            RecipeTag::class,
            RecipeReview::class,
            RecipeFavorite::class,
            RecipeReport::class
        ]
    )
    @EnableJpaRepositories(
        basePackageClasses = [
            SauceRecipeRepository::class,
            RecipeFavoriteRepository::class,
            RecipeReviewRepository::class,
            RecipeReportRepository::class,
            MemberRepository::class
        ]
    )
    @Import(SauceRecipeRepositoryImpl::class)
    class JpaTestApplication
}
