package com.nugusauce.application.member

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
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import org.springframework.dao.DataIntegrityViolationException
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class MemberServiceTest {
    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var sauceRecipeRepository: SauceRecipeRepository

    @Mock
    private lateinit var recipeFavoriteRepository: RecipeFavoriteRepository

    @Mock
    private lateinit var recipeReviewRepository: RecipeReviewRepository

    private lateinit var service: MemberService

    @BeforeEach
    fun setUp() {
        service = MemberService(
            memberRepository,
            sauceRecipeRepository,
            recipeFavoriteRepository,
            recipeReviewRepository
        )
    }

    @Test
    fun `getMe returns setup required when nickname is missing`() {
        `when`(memberRepository.findById(1L))
            .thenReturn(Optional.of(Member(1L, "user@example.test", null)))

        val result = service.getMe(1L)

        assertEquals(1L, result.id)
        assertEquals("사용자 1", result.displayName)
        assertTrue(result.profileSetupRequired)
    }

    @Test
    fun `getPublicProfile returns profile with visible recipes and favorites`() {
        val member = Member(2L, "public@example.test", null, nickname = "마라초보")
        val authoredRecipe = recipe(id = 10L, author = member)
        val visibleFavorite = recipe(id = 11L)
        val hiddenFavorite = recipe(id = 12L, visibility = RecipeVisibility.HIDDEN)
        `when`(memberRepository.findById(2L)).thenReturn(Optional.of(member))
        `when`(
            sauceRecipeRepository.findAllByAuthorIdAndVisibilityOrderByCreatedAtDesc(
                2L,
                RecipeVisibility.VISIBLE
            )
        ).thenReturn(listOf(authoredRecipe))
        `when`(recipeFavoriteRepository.findAllByMemberIdOrderByCreatedAtDesc(2L))
            .thenReturn(
                listOf(
                    RecipeFavorite(recipe = visibleFavorite, member = member),
                    RecipeFavorite(recipe = hiddenFavorite, member = member)
                )
            )
        `when`(recipeReviewRepository.countTasteTagsByRecipeIds(setOf(10L, 11L))).thenReturn(emptyList())

        val result = service.getPublicProfile(2L)

        assertEquals(2L, result.id)
        assertEquals("마라초보", result.displayName)
        assertFalse(result.profileSetupRequired)
        assertEquals(listOf(10L), result.recipes.map { it.id })
        assertEquals(listOf(11L), result.favoriteRecipes.map { it.id })
    }

    @Test
    fun `updateMe trims and stores valid nickname`() {
        val member = Member(1L, "user@example.test", null)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(memberRepository.existsByNicknameAndIdNot("소스장인", 1L)).thenReturn(false)

        val result = service.updateMe(MemberCommand.UpdateMe(1L, "  소스장인  "))

        assertEquals("소스장인", member.nickname)
        assertEquals("소스장인", result.displayName)
        assertFalse(result.profileSetupRequired)
    }

    @Test
    fun `updateMe rejects duplicate nickname`() {
        val member = Member(1L, "user@example.test", null)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(memberRepository.existsByNicknameAndIdNot("소스장인", 1L)).thenReturn(true)

        val exception = assertThrows(BusinessException::class.java) {
            service.updateMe(MemberCommand.UpdateMe(1L, "소스장인"))
        }

        assertEquals(ErrorCode.DUPLICATE_NICKNAME, exception.errorCode)
    }

    @Test
    fun `updateMe rejects invalid nickname`() {
        val member = Member(1L, "user@example.test", null)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        val exception = assertThrows(BusinessException::class.java) {
            service.updateMe(MemberCommand.UpdateMe(1L, "소스 장인"))
        }

        assertEquals(ErrorCode.INVALID_NICKNAME, exception.errorCode)
    }

    @Test
    fun `updateMe maps nickname unique constraint race to duplicate nickname`() {
        val member = Member(1L, "user@example.test", null)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(memberRepository.existsByNicknameAndIdNot("소스장인", 1L)).thenReturn(false)
        `when`(memberRepository.saveAndFlush(member))
            .thenThrow(DataIntegrityViolationException("Duplicate entry for key 'uk_member_nickname'"))

        val exception = assertThrows(BusinessException::class.java) {
            service.updateMe(MemberCommand.UpdateMe(1L, "소스장인"))
        }

        assertEquals(ErrorCode.DUPLICATE_NICKNAME, exception.errorCode)
    }

    private fun recipe(
        id: Long,
        author: Member? = null,
        visibility: RecipeVisibility = RecipeVisibility.VISIBLE
    ): SauceRecipe {
        return SauceRecipe(
            id = id,
            title = "건희 소스 $id",
            description = "설명",
            spiceLevel = 3,
            richnessLevel = 4,
            authorType = if (author == null) RecipeAuthorType.CURATED else RecipeAuthorType.USER,
            author = author,
            visibility = visibility
        )
    }
}
