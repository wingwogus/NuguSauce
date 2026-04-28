package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.report.RecipeReport
import com.nugusauce.domain.recipe.report.RecipeReportRepository
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
import org.mockito.Mockito
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class RecipeModerationServiceTest {
    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var sauceRecipeRepository: SauceRecipeRepository

    @Mock
    private lateinit var recipeReportRepository: RecipeReportRepository

    private lateinit var service: RecipeModerationService

    @BeforeEach
    fun setUp() {
        service = RecipeModerationService(
            memberRepository,
            sauceRecipeRepository,
            recipeReportRepository
        )
    }

    @Test
    fun `report stores authenticated report without exposing reporter`() {
        val reporter = Member(1L, "reporter@example.test", null)
        val recipe = recipe()
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(reporter))
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(recipe))
        `when`(recipeReportRepository.existsByRecipeAndReporter(10L, 1L)).thenReturn(false)
        `when`(recipeReportRepository.save(Mockito.any(RecipeReport::class.java)))
            .thenAnswer { it.getArgument(0) }

        val result = service.report(RecipeCommand.CreateReport(1L, 10L, "부적절한 내용"))

        assertEquals(10L, result.recipeId)
        assertEquals("부적절한 내용", result.reason)
    }

    @Test
    fun `report rejects duplicate report`() {
        val reporter = Member(1L, "reporter@example.test", null)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(reporter))
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(recipe()))
        `when`(recipeReportRepository.existsByRecipeAndReporter(10L, 1L)).thenReturn(true)

        val exception = assertThrows(BusinessException::class.java) {
            service.report(RecipeCommand.CreateReport(1L, 10L, "중복"))
        }

        assertEquals(ErrorCode.DUPLICATE_REPORT, exception.errorCode)
    }

    @Test
    fun `updateVisibility hides recipe`() {
        val recipe = recipe()
        `when`(sauceRecipeRepository.findById(10L)).thenReturn(Optional.of(recipe))
        `when`(sauceRecipeRepository.save(recipe)).thenReturn(recipe)

        val result = service.updateVisibility(
            RecipeCommand.UpdateVisibility(
                recipeId = 10L,
                visibility = RecipeCommand.Visibility.HIDDEN
            )
        )

        assertEquals("HIDDEN", result.visibility)
        assertEquals("NuguSauce", result.authorName)
        assertEquals(RecipeVisibility.HIDDEN, recipe.visibility)
    }

    private fun recipe(): SauceRecipe {
        return SauceRecipe(
            id = 10L,
            title = "건희 소스",
            description = "설명",
            spiceLevel = 3,
            richnessLevel = 4,
            authorType = RecipeAuthorType.CURATED
        )
    }
}
