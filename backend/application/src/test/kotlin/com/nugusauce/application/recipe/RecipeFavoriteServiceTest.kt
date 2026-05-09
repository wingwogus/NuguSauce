package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.application.media.MediaResult
import com.nugusauce.application.media.VerifiedUpload
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.favorite.RecipeFavorite
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mockito
import org.mockito.Mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import java.time.Instant
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class RecipeFavoriteServiceTest {
    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var sauceRecipeRepository: SauceRecipeRepository

    @Mock
    private lateinit var recipeFavoriteRepository: RecipeFavoriteRepository

    @Mock
    private lateinit var recipeReviewRepository: RecipeReviewRepository

    private lateinit var service: RecipeFavoriteService

    @BeforeEach
    fun setUp() {
        service = RecipeFavoriteService(
            memberRepository,
            sauceRecipeRepository,
            recipeFavoriteRepository,
            recipeReviewRepository,
            ImageUrlResolver(TestImageStoragePort)
        )
    }

    @Test
    fun `listMyRecipes returns visible recipes authored by member`() {
        val author = member()
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(author))
        `when`(
            sauceRecipeRepository.findAllByAuthorIdAndVisibilityOrderByCreatedAtDesc(
                1L,
                RecipeVisibility.VISIBLE
            )
        ).thenReturn(listOf(recipe(author = author)))
        `when`(recipeReviewRepository.countTasteTagsByRecipeIds(setOf(10L))).thenReturn(emptyList())
        `when`(recipeFavoriteRepository.findRecipeIdsByMemberAndRecipeIds(1L, setOf(10L)))
            .thenReturn(setOf(10L))

        val results = service.listMyRecipes(RecipeCommand.MemberRecipes(1L))

        assertEquals(1, results.size)
        assertEquals("VISIBLE", results.first().visibility)
        assertEquals(true, results.first().isFavorite)
        verify(sauceRecipeRepository).findAllByAuthorIdAndVisibilityOrderByCreatedAtDesc(
            1L,
            RecipeVisibility.VISIBLE
        )
        verify(recipeFavoriteRepository).findRecipeIdsByMemberAndRecipeIds(1L, setOf(10L))
    }

    @Test
    fun `listFavorites excludes hidden recipes`() {
        val member = member()
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(recipeFavoriteRepository.findAllByMemberIdOrderByCreatedAtDesc(1L))
            .thenReturn(
                listOf(
                    RecipeFavorite(recipe = recipe(), member = member),
                    RecipeFavorite(recipe = recipe(visibility = RecipeVisibility.HIDDEN), member = member)
                )
            )
        `when`(recipeReviewRepository.countTasteTagsByRecipeIds(setOf(10L))).thenReturn(emptyList())

        val results = service.listFavorites(RecipeCommand.MemberRecipes(1L))

        assertEquals(1, results.size)
        assertEquals("VISIBLE", results.first().visibility)
        assertEquals(true, results.first().isFavorite)
    }

    @Test
    fun `addFavorite rejects duplicate favorite`() {
        val recipe = recipe()
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member()))
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(recipe))
        `when`(recipeFavoriteRepository.existsByRecipeAndMember(10L, 1L)).thenReturn(true)

        val exception = assertThrows(BusinessException::class.java) {
            service.addFavorite(RecipeCommand.FavoriteRecipe(1L, 10L))
        }

        assertEquals(ErrorCode.DUPLICATE_FAVORITE, exception.errorCode)
        assertEquals(0, recipe.favoriteCount)
    }

    @Test
    fun `addFavorite increments recipe favorite count after saving favorite`() {
        val member = member()
        val recipe = recipe()
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(recipe))
        `when`(recipeFavoriteRepository.existsByRecipeAndMember(10L, 1L)).thenReturn(false)
        `when`(recipeFavoriteRepository.save(Mockito.any(RecipeFavorite::class.java)))
            .thenAnswer { it.getArgument(0) }

        val result = service.addFavorite(RecipeCommand.FavoriteRecipe(1L, 10L))

        assertEquals(10L, result.recipeId)
        verify(sauceRecipeRepository).incrementFavoriteCount(10L, result.createdAt)
    }

    @Test
    fun `removeFavorite deletes existing favorite`() {
        val recipe = recipe(favoriteCount = 2)
        val favorite = RecipeFavorite(recipe = recipe, member = member())
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member()))
        `when`(recipeFavoriteRepository.findByRecipeAndMember(10L, 1L)).thenReturn(favorite)

        service.removeFavorite(RecipeCommand.FavoriteRecipe(1L, 10L))

        verify(recipeFavoriteRepository).delete(favorite)
        val decrementInvocation = Mockito.mockingDetails(sauceRecipeRepository).invocations
            .single { it.method.name == "decrementFavoriteCount" }
        assertEquals(10L, decrementInvocation.arguments[0])
        assertEquals(true, decrementInvocation.arguments[1] is Instant)
    }

    @Test
    fun `removeFavorite rejects missing favorite`() {
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member()))
        `when`(recipeFavoriteRepository.findByRecipeAndMember(10L, 1L)).thenReturn(null)

        val exception = assertThrows(BusinessException::class.java) {
            service.removeFavorite(RecipeCommand.FavoriteRecipe(1L, 10L))
        }

        assertEquals(ErrorCode.FAVORITE_NOT_FOUND, exception.errorCode)
    }

    private fun member(): Member {
        return Member(1L, "user@example.test", null, nickname = "소스장인")
    }

    private fun recipe(
        author: Member? = null,
        visibility: RecipeVisibility = RecipeVisibility.VISIBLE,
        favoriteCount: Int = 0
    ): SauceRecipe {
        return SauceRecipe(
            id = 10L,
            title = "건희 소스",
            description = "설명",
            spiceLevel = 3,
            richnessLevel = 4,
            author = author,
            visibility = visibility,
            favoriteCount = favoriteCount
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
