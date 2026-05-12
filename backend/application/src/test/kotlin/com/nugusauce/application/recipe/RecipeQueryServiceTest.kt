package com.nugusauce.application.recipe

import com.nugusauce.application.common.cursor.CursorCodec
import com.nugusauce.application.common.cursor.CursorShape
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
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeHomeCondition
import com.nugusauce.domain.recipe.sauce.SauceRecipeHomeSections
import com.nugusauce.domain.recipe.sauce.SauceRecipePageCondition
import com.nugusauce.domain.recipe.sauce.SauceRecipePageSlice
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import com.nugusauce.domain.recipe.sauce.SauceRecipeSort
import com.nugusauce.domain.recipe.tag.RecipeTag
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
import java.time.Instant
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
            ImageUrlResolver(TestImageStoragePort),
            RecipeTagDerivationPolicy()
        )
    }

    @Test
    fun `search delegates normalized condition to repository and maps summaries`() {
        val condition = SauceRecipePageCondition(keyword = "건희", limit = 20)
        `when`(sauceRecipeRepository.searchRecipePage(condition))
            .thenReturn(page(recipe(title = "건희 소스")))

        val results = service.search(RecipeCommand.SearchRecipes(q = "  건희  "))

        assertEquals(1, results.items.size)
        assertEquals("건희 소스", results.items.first().title)
        assertEquals(false, results.items.first().isFavorite)
        assertEquals(false, results.hasNext)
        verify(sauceRecipeRepository).searchRecipePage(condition)
        verifyNoInteractions(recipeFavoriteRepository)
    }

    @Test
    fun `search marks favorite summaries for authenticated viewer with one bulk lookup`() {
        val recipes = listOf(
            recipe(id = 10L, title = "건희 소스"),
            recipe(id = 20L, title = "찜한 소스")
        )
        `when`(sauceRecipeRepository.searchRecipePage(SauceRecipePageCondition(limit = 20)))
            .thenReturn(page(recipes))
        `when`(recipeFavoriteRepository.findRecipeIdsByMemberAndRecipeIds(1L, setOf(10L, 20L)))
            .thenReturn(setOf(20L))

        val results = service.search(RecipeCommand.SearchRecipes(viewerMemberId = 1L))

        assertEquals(listOf(false, true), results.items.map { it.isFavorite })
        verify(recipeFavoriteRepository).findRecipeIdsByMemberAndRecipeIds(1L, setOf(10L, 20L))
    }

    @Test
    fun `search skips favorite lookup for empty result list`() {
        `when`(sauceRecipeRepository.searchRecipePage(SauceRecipePageCondition(limit = 20)))
            .thenReturn(SauceRecipePageSlice(recipes = emptyList(), hasNext = false))

        val results = service.search(RecipeCommand.SearchRecipes(viewerMemberId = 1L))

        assertEquals(emptyList<RecipeResult.RecipeSummary>(), results.items)
        verifyNoInteractions(recipeFavoriteRepository)
    }

    @Test
    fun `search encodes next cursor from last returned row when page has next`() {
        val condition = SauceRecipePageCondition(limit = 1)
        `when`(sauceRecipeRepository.searchRecipePage(condition))
            .thenReturn(page(listOf(recipe(id = 10L, title = "건희 소스")), hasNext = true))

        val result = service.search(RecipeCommand.SearchRecipes(limit = 1))

        assertEquals(listOf("건희 소스"), result.items.map { it.title })
        assertEquals(true, result.hasNext)
        assertNotEquals(null, result.nextCursor)
    }

    @Test
    fun `search rejects malformed cursor before repository lookup`() {
        val exception = assertThrows(BusinessException::class.java) {
            service.search(RecipeCommand.SearchRecipes(cursor = "not-base64"))
        }

        assertEquals(ErrorCode.INVALID_INPUT, exception.errorCode)
        verifyNoInteractions(sauceRecipeRepository)
    }

    @Test
    fun `search delegates decoded cursor offset to repository`() {
        val cursor = CursorCodec().encode(
            CursorShape(
                mapOf(
                    "q" to null,
                    "tagIds" to "",
                    "ingredientIds" to "",
                    "sort" to "popular",
                    "limit" to "20"
                )
            ),
            offset = 20
        )
        val condition = SauceRecipePageCondition(limit = 20, offset = 20)
        `when`(sauceRecipeRepository.searchRecipePage(condition))
            .thenReturn(page(recipe(id = 30L, title = "두 번째 페이지 소스")))

        val results = service.search(RecipeCommand.SearchRecipes(cursor = cursor))

        assertEquals(listOf("두 번째 페이지 소스"), results.items.map { it.title })
        verify(sauceRecipeRepository).searchRecipePage(condition)
    }

    @Test
    fun `search delegates tag and ingredient filters and returns recipe tags`() {
        val nutty = RecipeTag(id = 1L, name = "고소함")
        val condition = SauceRecipePageCondition(
            tagIds = setOf(1L),
            ingredientIds = setOf(9L),
            sort = SauceRecipeSort.RECENT,
            limit = 20
        )
        `when`(sauceRecipeRepository.searchRecipePage(condition))
            .thenReturn(page(recipe(id = 10L, title = "건희 소스", tags = listOf(nutty))))

        val results = service.search(
            RecipeCommand.SearchRecipes(
                tagIds = listOf(1L, 1L),
                ingredientIds = listOf(9L),
                sort = RecipeCommand.RecipeSort.RECENT
            )
        )

        assertEquals(1, results.items.size)
        assertEquals("건희 소스", results.items.first().title)
        assertEquals("고소함", results.items.first().tags.first().name)
        verify(sauceRecipeRepository).searchRecipePage(condition)
    }

    @Test
    fun `home loads fixed sections once and personalizes favorites in bulk`() {
        val popular = recipe(id = 20L, title = "인기 소스")
        val recent = recipe(id = 30L, title = "최신 소스")
        val condition = SauceRecipeHomeCondition(
            popularLimit = 5,
            recentLimit = 10
        )
        `when`(sauceRecipeRepository.searchHomeSections(condition))
            .thenReturn(
                SauceRecipeHomeSections(
                    popular = listOf(popular),
                    recent = listOf(recent)
                )
            )
        `when`(recipeFavoriteRepository.findRecipeIdsByMemberAndRecipeIds(1L, setOf(20L, 30L)))
            .thenReturn(setOf(20L))

        val result = service.home(RecipeCommand.HomeFeed(viewerMemberId = 1L))

        assertEquals(listOf("인기 소스"), result.popularTop.map { it.title })
        assertEquals(listOf("최신 소스"), result.recentTop.map { it.title })
        assertEquals(true, result.popularTop.first().isFavorite)
        verify(sauceRecipeRepository).searchHomeSections(condition)
        verify(recipeFavoriteRepository).findRecipeIdsByMemberAndRecipeIds(1L, setOf(20L, 30L))
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

        val result = service.getDetail(10L)

        assertEquals(7L, result.authorId)
        assertEquals("소스장인", result.authorName)
    }

    @Test
    fun `getDetail includes current member favorite state when member is present`() {
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(recipe()))
        `when`(recipeFavoriteRepository.existsByRecipeAndMember(10L, 1L)).thenReturn(true)

        val result = service.getDetail(10L, memberId = 1L)

        assertEquals(true, result.isFavorite)
    }

    @Test
    fun `getDetail defaults favorite state to false for anonymous users`() {
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(recipe()))

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
        createdAt: Instant = Instant.parse("2026-04-25T00:00:00Z"),
        tags: List<RecipeTag> = emptyList()
    ): SauceRecipe {
        return SauceRecipe(
            id = id,
            title = title,
            description = "설명",
            spiceLevel = 3,
            richnessLevel = 4,
            author = author,
            visibility = visibility,
            createdAt = createdAt
        ).apply {
            this.reviewCount = reviewCount
            this.averageRating = averageRating
            this.lastReviewedAt = lastReviewedAt
            this.tags.addAll(tags)
        }
    }

    private fun page(
        vararg recipes: SauceRecipe,
        hasNext: Boolean = false
    ): SauceRecipePageSlice {
        return page(recipes.toList(), hasNext)
    }

    private fun page(
        recipes: List<SauceRecipe>,
        hasNext: Boolean = false
    ): SauceRecipePageSlice {
        return SauceRecipePageSlice(
            recipes = recipes,
            hasNext = hasNext
        )
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
