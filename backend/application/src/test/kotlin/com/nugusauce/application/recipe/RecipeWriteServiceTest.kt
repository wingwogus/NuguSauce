package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.ingredient.Ingredient
import com.nugusauce.domain.recipe.ingredient.IngredientRepository
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import java.math.BigDecimal
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class RecipeWriteServiceTest {
    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var ingredientRepository: IngredientRepository

    @Mock
    private lateinit var sauceRecipeRepository: SauceRecipeRepository

    private lateinit var service: RecipeWriteService

    @BeforeEach
    fun setUp() {
        service = RecipeWriteService(
            memberRepository,
            ingredientRepository,
            sauceRecipeRepository
        )
    }

    @Test
    fun `create stores user recipe with ingredients`() {
        val member = Member(1L, "user@example.test", null)
        val ingredient = Ingredient(1L, "참기름", "oil")
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(ingredientRepository.findAllById(setOf(1L))).thenReturn(listOf(ingredient))
        `when`(sauceRecipeRepository.save(Mockito.any(SauceRecipe::class.java)))
            .thenAnswer { it.getArgument(0) }

        val result = service.create(
            RecipeCommand.CreateRecipe(
                authorId = 1L,
                title = "내 소스",
                description = "고소한 조합",
                ingredients = listOf(
                    RecipeCommand.IngredientInput(
                        ingredientId = 1L,
                        amount = BigDecimal.ONE,
                        unit = "스푼"
                    )
                )
            )
        )

        assertEquals("내 소스", result.title)
        assertEquals(1, result.ingredients.size)
        assertEquals("참기름", result.ingredients.first().name)
        assertEquals(0, result.spiceLevel)
        assertEquals(0, result.richnessLevel)
        assertTrue(result.tags.isEmpty())
    }

    @Test
    fun `create rejects ingredient without amount or ratio`() {
        `when`(memberRepository.findById(1L)).thenReturn(
            Optional.of(Member(1L, "user@example.test", null))
        )

        val exception = assertThrows(BusinessException::class.java) {
            service.create(
                RecipeCommand.CreateRecipe(
                    authorId = 1L,
                    title = "내 소스",
                    description = "고소한 조합",
                    ingredients = listOf(RecipeCommand.IngredientInput(ingredientId = 1L))
                )
            )
        }

        assertEquals(ErrorCode.INVALID_RECIPE_INGREDIENT_AMOUNT, exception.errorCode)
    }
}
