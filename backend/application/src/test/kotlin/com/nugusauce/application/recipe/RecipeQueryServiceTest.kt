package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.domain.recipe.ingredient.IngredientRepository
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.review.RecipeReviewTagCountProjection
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
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
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

    private lateinit var service: RecipeQueryService

    @BeforeEach
    fun setUp() {
        service = RecipeQueryService(
            sauceRecipeRepository,
            ingredientRepository,
            recipeTagRepository,
            recipeReviewRepository
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

    private fun recipe(
        id: Long = 10L,
        title: String = "레시피",
        visibility: RecipeVisibility = RecipeVisibility.VISIBLE
    ): SauceRecipe {
        return SauceRecipe(
            id = id,
            title = title,
            description = "설명",
            spiceLevel = 3,
            richnessLevel = 4,
            authorType = RecipeAuthorType.CURATED,
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
}
