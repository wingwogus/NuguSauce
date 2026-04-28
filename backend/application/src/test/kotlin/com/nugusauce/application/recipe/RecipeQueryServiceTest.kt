package com.nugusauce.application.recipe

import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.application.media.MediaResult
import com.nugusauce.application.media.VerifiedUpload
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
import com.nugusauce.domain.recipe.tag.RecipeTagRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito.`when`
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
            RecipeImageUrlResolver(TestImageStoragePort)
        )
    }

    @Test
    fun `search returns only visible recipes from repository`() {
        `when`(sauceRecipeRepository.findAllByVisibility(RecipeVisibility.VISIBLE))
            .thenReturn(listOf(recipe(title = "건희 소스")))
        `when`(recipeReviewRepository.countTasteTagsByRecipeIds(setOf(10L))).thenReturn(emptyList())

        val results = service.search(RecipeCommand.SearchRecipes(q = "건희"))

        assertEquals(1, results.size)
        assertEquals("건희 소스", results.first().title)
    }

    @Test
    fun `search filters by review tags and returns tag counts`() {
        `when`(sauceRecipeRepository.findAllByVisibility(RecipeVisibility.VISIBLE))
            .thenReturn(
                listOf(
                    recipe(id = 10L, title = "건희 소스"),
                    recipe(id = 20L, title = "고수 소스")
                )
            )
        `when`(recipeReviewRepository.countTasteTagsByRecipeIds(setOf(10L, 20L)))
            .thenReturn(
                listOf(
                    tagCount(recipeId = 10L, tagId = 1L, tagName = "고소함", tagCount = 3),
                    tagCount(recipeId = 10L, tagId = 2L, tagName = "매콤함", tagCount = 1),
                    tagCount(recipeId = 20L, tagId = 4L, tagName = "상큼함", tagCount = 2)
                )
            )

        val results = service.search(RecipeCommand.SearchRecipes(tagIds = listOf(1L)))

        assertEquals(1, results.size)
        assertEquals("건희 소스", results.first().title)
        assertEquals("고소함", results.first().reviewTags.first().name)
        assertEquals(3L, results.first().reviewTags.first().count)
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
        author: Member? = null
    ): SauceRecipe {
        return SauceRecipe(
            id = id,
            title = title,
            description = "설명",
            spiceLevel = 3,
            richnessLevel = 4,
            authorType = if (author == null) RecipeAuthorType.CURATED else RecipeAuthorType.USER,
            author = author,
            visibility = visibility
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
    }
}
