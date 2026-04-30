package com.nugusauce.application.recipe

import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.application.media.MediaResult
import com.nugusauce.application.media.VerifiedUpload
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.ingredient.IngredientRepository
import com.nugusauce.domain.recipe.review.RecipeReview
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.review.RecipeReviewTagCountProjection
import com.nugusauce.domain.recipe.sauce.RecipeAuthorType
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import com.nugusauce.domain.recipe.sauce.SauceRecipeSearchCondition
import com.nugusauce.domain.recipe.sauce.SauceRecipeSort
import com.nugusauce.domain.recipe.tag.RecipeTagRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.Mockito.verify
import org.mockito.Mockito.verifyNoInteractions
import org.mockito.junit.jupiter.MockitoExtension
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class RecipeQueryServiceTest {
    @Mock
    private lateinit var sauceRecipeRepository: SauceRecipeRepository

    @Mock
    private lateinit var ingredientRepository: IngredientRepository

    @Mock
    private lateinit var recipeTagRepository: RecipeTagRepository

    @Mock
    private lateinit var recipeReviewRepository: RecipeReviewRepository

    @Mock
    private lateinit var recipeFavoriteRepository: RecipeFavoriteRepository

    private lateinit var service: RecipeQueryService

    @BeforeEach
    fun setUp() {
        service = RecipeQueryService(
            sauceRecipeRepository,
            ingredientRepository,
            recipeTagRepository,
            recipeReviewRepository,
            recipeFavoriteRepository,
            ImageUrlResolver(TestImageStoragePort)
        )
    }

    @Test
    fun `search delegates normalized condition to repository and maps summaries`() {
        val condition = SauceRecipeSearchCondition(keyword = "건희")
        `when`(sauceRecipeRepository.searchVisibleRecipes(condition))
            .thenReturn(listOf(recipe(title = "건희 소스")))
        `when`(recipeReviewRepository.countTasteTagsByRecipeIds(setOf(10L))).thenReturn(emptyList())

        val results = service.search(RecipeCommand.SearchRecipes(q = "  건희  "))

        assertEquals(1, results.size)
        assertEquals("건희 소스", results.first().title)
        assertEquals(false, results.first().isFavorite)
        verify(sauceRecipeRepository).searchVisibleRecipes(condition)
        verifyNoInteractions(recipeFavoriteRepository)
    }

    @Test
    fun `search marks favorite summaries for authenticated viewer with one bulk lookup`() {
        val recipes = listOf(
            recipe(id = 10L, title = "건희 소스"),
            recipe(id = 20L, title = "찜한 소스")
        )
        `when`(sauceRecipeRepository.searchVisibleRecipes(SauceRecipeSearchCondition()))
            .thenReturn(recipes)
        `when`(recipeReviewRepository.countTasteTagsByRecipeIds(setOf(10L, 20L))).thenReturn(emptyList())
        `when`(recipeFavoriteRepository.findRecipeIdsByMemberAndRecipeIds(1L, setOf(10L, 20L)))
            .thenReturn(setOf(20L))

        val results = service.search(RecipeCommand.SearchRecipes(viewerMemberId = 1L))

        assertEquals(listOf(false, true), results.map { it.isFavorite })
        verify(recipeFavoriteRepository).findRecipeIdsByMemberAndRecipeIds(1L, setOf(10L, 20L))
    }

    @Test
    fun `search skips favorite lookup for empty result list`() {
        `when`(sauceRecipeRepository.searchVisibleRecipes(SauceRecipeSearchCondition()))
            .thenReturn(emptyList())

        val results = service.search(RecipeCommand.SearchRecipes(viewerMemberId = 1L))

        assertEquals(emptyList<RecipeResult.RecipeSummary>(), results)
        verifyNoInteractions(recipeFavoriteRepository)
    }

    @Test
    fun `search delegates tag and ingredient filters and returns review tag counts`() {
        val condition = SauceRecipeSearchCondition(
            tagIds = setOf(1L),
            ingredientIds = setOf(9L),
            sort = SauceRecipeSort.RATING
        )
        `when`(sauceRecipeRepository.searchVisibleRecipes(condition))
            .thenReturn(listOf(recipe(id = 10L, title = "건희 소스")))
        `when`(recipeReviewRepository.countTasteTagsByRecipeIds(setOf(10L)))
            .thenReturn(
                listOf(
                    tagCount(recipeId = 10L, tagId = 1L, tagName = "고소함", tagCount = 3),
                    tagCount(recipeId = 10L, tagId = 2L, tagName = "매콤함", tagCount = 1)
                )
            )

        val results = service.search(
            RecipeCommand.SearchRecipes(
                tagIds = listOf(1L, 1L),
                ingredientIds = listOf(9L),
                sort = RecipeCommand.RecipeSort.RATING
            )
        )

        assertEquals(1, results.size)
        assertEquals("건희 소스", results.first().title)
        assertEquals("고소함", results.first().reviewTags.first().name)
        assertEquals(3L, results.first().reviewTags.first().count)
        verify(sauceRecipeRepository).searchVisibleRecipes(condition)
    }

    @Test
    fun `hot search delegates seven day window to repository`() {
        val now = Instant.parse("2026-04-29T00:00:00Z")
        service = service(clock = Clock.fixed(now, ZoneOffset.UTC))
        val olderPopular = recipe(
            id = 10L,
            title = "누적 인기 소스",
            reviewCount = 80,
            averageRating = 4.9,
            lastReviewedAt = now.minus(20, ChronoUnit.DAYS)
        )
        val hotRecipe = recipe(
            id = 20L,
            title = "요즘 핫한 소스",
            reviewCount = 2,
            averageRating = 4.0,
            lastReviewedAt = now.minus(1, ChronoUnit.DAYS)
        )
        val condition = SauceRecipeSearchCondition(
            sort = SauceRecipeSort.HOT,
            hotSince = now.minus(7, ChronoUnit.DAYS)
        )
        `when`(sauceRecipeRepository.searchVisibleRecipes(condition))
            .thenReturn(listOf(hotRecipe, olderPopular))
        `when`(recipeReviewRepository.countTasteTagsByRecipeIds(setOf(10L, 20L))).thenReturn(emptyList())

        val results = service.search(RecipeCommand.SearchRecipes(sort = RecipeCommand.RecipeSort.HOT))

        assertEquals(listOf("요즘 핫한 소스", "누적 인기 소스"), results.map { it.title })
        verify(sauceRecipeRepository).searchVisibleRecipes(condition)
    }

    @Test
    fun `getDetail rejects hidden recipe`() {
        `when`(sauceRecipeRepository.findById(10L))
            .thenReturn(Optional.of(recipe(visibility = RecipeVisibility.HIDDEN)))

        val exception = assertThrows(BusinessException::class.java) {
            service.getDetail(10L)
        }

        assertEquals(ErrorCode.HIDDEN_RECIPE, exception.errorCode)
    }

    @Test
    fun `getDetail includes user recipe author nickname`() {
        val author = Member(7L, "maker@example.test", null, nickname = "소스장인")
        `when`(sauceRecipeRepository.findById(10L))
            .thenReturn(Optional.of(recipe(author = author)))
        `when`(recipeReviewRepository.countTasteTagsByRecipeIds(setOf(10L))).thenReturn(emptyList())

        val result = service.getDetail(10L)

        assertEquals("USER", result.authorType)
        assertEquals(7L, result.authorId)
        assertEquals("소스장인", result.authorName)
    }

    @Test
    fun `getDetail includes current member favorite state when member is present`() {
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(recipe()))
        `when`(recipeReviewRepository.countTasteTagsByRecipeIds(setOf(10L))).thenReturn(emptyList())
        `when`(recipeFavoriteRepository.existsByRecipeAndMember(10L, 1L)).thenReturn(true)

        val result = service.getDetail(10L, memberId = 1L)

        assertEquals(true, result.isFavorite)
    }

    @Test
    fun `getDetail defaults favorite state to false for anonymous users`() {
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(recipe()))
        `when`(recipeReviewRepository.countTasteTagsByRecipeIds(setOf(10L))).thenReturn(emptyList())

        val result = service.getDetail(10L)

        assertEquals(false, result.isFavorite)
    }

    @Test
    fun `listReviews includes safe public author name`() {
        val recipe = recipe()
        val review = RecipeReview(
            id = 30L,
            recipe = recipe,
            author = Member(7L, "reviewer@example.test", null, nickname = "리뷰장인"),
            rating = 4,
            text = "고소해요"
        )
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(recipe))
        `when`(recipeReviewRepository.findAllByRecipeIdOrderByCreatedAtDesc(10L)).thenReturn(listOf(review))

        val results = service.listReviews(10L)

        assertEquals("리뷰장인", results.first().authorName)
        assertEquals(7L, results.first().authorId)
        assertNotEquals("reviewer@example.test", results.first().authorName)
        assertEquals("고소해요", results.first().text)
    }

    private fun recipe(
        id: Long = 10L,
        title: String = "레시피",
        visibility: RecipeVisibility = RecipeVisibility.VISIBLE,
        author: Member? = null,
        reviewCount: Int = 0,
        averageRating: Double = 0.0,
        lastReviewedAt: Instant? = null,
        createdAt: Instant = Instant.parse("2026-04-25T00:00:00Z")
    ): SauceRecipe {
        return SauceRecipe(
            id = id,
            title = title,
            description = "설명",
            spiceLevel = 3,
            richnessLevel = 4,
            authorType = if (author == null) RecipeAuthorType.CURATED else RecipeAuthorType.USER,
            author = author,
            visibility = visibility,
            createdAt = createdAt
        ).apply {
            this.reviewCount = reviewCount
            this.averageRating = averageRating
            this.lastReviewedAt = lastReviewedAt
        }
    }

    private fun service(clock: Clock): RecipeQueryService {
        return RecipeQueryService(
            sauceRecipeRepository,
            ingredientRepository,
            recipeTagRepository,
            recipeReviewRepository,
            recipeFavoriteRepository,
            ImageUrlResolver(TestImageStoragePort),
            clock
        )
    }

    private fun tagCount(
        recipeId: Long,
        tagId: Long,
        tagName: String,
        tagCount: Long
    ): RecipeReviewTagCountProjection {
        return object : RecipeReviewTagCountProjection {
            override val recipeId: Long = recipeId
            override val tagId: Long = tagId
            override val tagName: String = tagName
            override val tagCount: Long = tagCount
        }
    }

    private object TestImageStoragePort : ImageStoragePort {
        override fun createUploadTarget(
            providerKey: String,
            contentType: String,
            expiresAt: Instant
        ): MediaResult.UploadTarget {
            throw UnsupportedOperationException()
        }

        override fun verifyUpload(providerKey: String): VerifiedUpload {
            throw UnsupportedOperationException()
        }

        override fun displayUrl(providerKey: String): String {
            return "https://cdn.example.test/$providerKey"
        }

        override fun delete(providerKey: String) {
            throw UnsupportedOperationException()
        }
    }
}
