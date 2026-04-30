package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.application.media.MediaResult
import com.nugusauce.application.media.VerifiedUpload
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.review.RecipeReview
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeAuthorType
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import com.nugusauce.domain.recipe.tag.RecipeTagRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class RecipeReviewServiceTest {
    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var sauceRecipeRepository: SauceRecipeRepository

    @Mock
    private lateinit var recipeReviewRepository: RecipeReviewRepository

    @Mock
    private lateinit var recipeTagRepository: RecipeTagRepository

    private lateinit var service: RecipeReviewService

    @BeforeEach
    fun setUp() {
        service = RecipeReviewService(
            memberRepository,
            sauceRecipeRepository,
            recipeReviewRepository,
            recipeTagRepository,
            ImageUrlResolver(TestImageStoragePort)
        )
    }

    @Test
    fun `create stores first review and updates summary`() {
        val member = Member(1L, "user@example.test", null, nickname = "리뷰장인")
        val recipe = recipe()
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(recipe))
        `when`(recipeReviewRepository.existsByRecipeAndAuthor(10L, 1L)).thenReturn(false)
        `when`(sauceRecipeRepository.save(recipe)).thenReturn(recipe)
        `when`(recipeReviewRepository.save(Mockito.any(RecipeReview::class.java)))
            .thenAnswer { it.getArgument(0) }

        val result = service.create(
            RecipeCommand.CreateReview(
                authorId = 1L,
                recipeId = 10L,
                rating = 5,
                text = "좋아요"
            )
        )

        assertEquals(1L, result.authorId)
        assertEquals("리뷰장인", result.authorName)
        assertEquals(5, result.rating)
        assertEquals(1, recipe.reviewCount)
        assertEquals(5.0, recipe.averageRating)
    }

    @Test
    fun `create rejects duplicate review`() {
        val member = Member(1L, "user@example.test", null)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(recipe()))
        `when`(recipeReviewRepository.existsByRecipeAndAuthor(10L, 1L)).thenReturn(true)

        val exception = assertThrows(BusinessException::class.java) {
            service.create(RecipeCommand.CreateReview(1L, 10L, 4, "중복"))
        }

        assertEquals(ErrorCode.DUPLICATE_REVIEW, exception.errorCode)
    }

    @Test
    fun `create rejects hidden recipe`() {
        val hidden = recipe(visibility = RecipeVisibility.HIDDEN)
        `when`(memberRepository.findById(1L)).thenReturn(
            Optional.of(Member(1L, "user@example.test", null))
        )
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(hidden))

        val exception = assertThrows(BusinessException::class.java) {
            service.create(RecipeCommand.CreateReview(1L, 10L, 4, "숨김"))
        }

        assertEquals(ErrorCode.HIDDEN_RECIPE, exception.errorCode)
    }

    private fun recipe(
        visibility: RecipeVisibility = RecipeVisibility.VISIBLE
    ): SauceRecipe {
        return SauceRecipe(
            id = 10L,
            title = "건희 소스",
            description = "설명",
            spiceLevel = 3,
            richnessLevel = 4,
            authorType = RecipeAuthorType.CURATED,
            visibility = visibility
        )
    }

    private object TestImageStoragePort : ImageStoragePort {
        override fun createUploadTarget(
            providerKey: String,
            contentType: String,
            expiresAt: java.time.Instant
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
