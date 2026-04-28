package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.favorite.RecipeFavorite
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeAuthorType
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
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
            recipeReviewRepository
        )
    }

    @Test
    fun `listMyRecipes returns recipes authored by member including own hidden recipes`() {
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member()))
        `when`(sauceRecipeRepository.findAllByAuthorIdOrderByCreatedAtDesc(1L))
            .thenReturn(listOf(recipe(author = member(), visibility = RecipeVisibility.HIDDEN)))
        `when`(recipeReviewRepository.countTasteTagsByRecipeIds(setOf(10L))).thenReturn(emptyList())

        val results = service.listMyRecipes(RecipeCommand.MemberRecipes(1L))

        assertEquals(1, results.size)
        assertEquals("HIDDEN", results.first().visibility)
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
    }

    @Test
    fun `addFavorite rejects duplicate favorite`() {
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member()))
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(recipe()))
        `when`(recipeFavoriteRepository.existsByRecipeAndMember(10L, 1L)).thenReturn(true)

        val exception = assertThrows(BusinessException::class.java) {
            service.addFavorite(RecipeCommand.FavoriteRecipe(1L, 10L))
        }

        assertEquals(ErrorCode.DUPLICATE_FAVORITE, exception.errorCode)
    }

    @Test
    fun `removeFavorite deletes existing favorite`() {
        val favorite = RecipeFavorite(recipe = recipe(), member = member())
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member()))
        `when`(recipeFavoriteRepository.findByRecipeAndMember(10L, 1L)).thenReturn(favorite)

        service.removeFavorite(RecipeCommand.FavoriteRecipe(1L, 10L))

        verify(recipeFavoriteRepository).delete(favorite)
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
        visibility: RecipeVisibility = RecipeVisibility.VISIBLE
    ): SauceRecipe {
        return SauceRecipe(
            id = 10L,
            title = "건희 소스",
            description = "설명",
            spiceLevel = 3,
            richnessLevel = 4,
            authorType = if (author == null) RecipeAuthorType.CURATED else RecipeAuthorType.USER,
            author = author,
            visibility = visibility
        )
    }
}
