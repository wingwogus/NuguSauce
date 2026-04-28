package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.application.media.MediaResult
import com.nugusauce.application.media.VerifiedUpload
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.media.MediaAssetRepository
import com.nugusauce.domain.media.MediaAssetStatus
import com.nugusauce.domain.media.MediaProvider
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
import java.time.Instant
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class RecipeWriteServiceTest {
    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var ingredientRepository: IngredientRepository

    @Mock
    private lateinit var sauceRecipeRepository: SauceRecipeRepository

    @Mock
    private lateinit var mediaAssetRepository: MediaAssetRepository

    private lateinit var service: RecipeWriteService

    @BeforeEach
    fun setUp() {
        service = RecipeWriteService(
            memberRepository,
            ingredientRepository,
            sauceRecipeRepository,
            mediaAssetRepository,
            RecipeImageUrlResolver(TestImageStoragePort)
        )
    }

    @Test
    fun `create stores user recipe with ingredients`() {
        val member = Member(1L, "user@example.test", null, nickname = "소스장인")
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
        assertEquals("소스장인", result.authorName)
        assertEquals(0, result.spiceLevel)
        assertEquals(0, result.richnessLevel)
        assertTrue(result.tags.isEmpty())
    }

    @Test
    fun `create attaches verified owner image asset`() {
        val member = Member(1L, "user@example.test", null, nickname = "소스장인")
        val ingredient = Ingredient(1L, "참기름", "oil")
        val imageAsset = MediaAsset(
            id = 20L,
            owner = member,
            provider = MediaProvider.CLOUDINARY,
            providerKey = "nugusauce/recipes/1/image",
            contentType = "image/jpeg",
            byteSize = 1000L
        )
        imageAsset.markVerified(
            contentType = "image/jpeg",
            byteSize = 1000L,
            width = 800,
            height = 600
        )
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(ingredientRepository.findAllById(setOf(1L))).thenReturn(listOf(ingredient))
        `when`(mediaAssetRepository.findById(20L)).thenReturn(Optional.of(imageAsset))
        `when`(sauceRecipeRepository.save(Mockito.any(SauceRecipe::class.java)))
            .thenAnswer { it.getArgument(0) }

        val result = service.create(
            RecipeCommand.CreateRecipe(
                authorId = 1L,
                title = "사진 소스",
                description = "사진 포함",
                imageId = 20L,
                ingredients = listOf(
                    RecipeCommand.IngredientInput(
                        ingredientId = 1L,
                        amount = BigDecimal.ONE,
                        unit = "스푼"
                    )
                )
            )
        )

        assertEquals("https://cdn.example.test/nugusauce/recipes/1/image", result.imageUrl)
        assertEquals(MediaAssetStatus.ATTACHED, imageAsset.status)
        assertEquals(0L, imageAsset.attachedRecipeId)
    }

    @Test
    fun `create rejects unverified image asset`() {
        val member = Member(1L, "user@example.test", null, nickname = "소스장인")
        val imageAsset = MediaAsset(
            id = 20L,
            owner = member,
            provider = MediaProvider.CLOUDINARY,
            providerKey = "nugusauce/recipes/1/image",
            contentType = "image/jpeg",
            byteSize = 1000L
        )
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(ingredientRepository.findAllById(setOf(1L))).thenReturn(listOf(Ingredient(1L, "참기름", "oil")))
        `when`(mediaAssetRepository.findById(20L)).thenReturn(Optional.of(imageAsset))

        val exception = assertThrows(BusinessException::class.java) {
            service.create(
                RecipeCommand.CreateRecipe(
                    authorId = 1L,
                    title = "사진 소스",
                    description = "사진 포함",
                    imageId = 20L,
                    ingredients = listOf(
                        RecipeCommand.IngredientInput(
                            ingredientId = 1L,
                            amount = BigDecimal.ONE
                        )
                    )
                )
            )
        }

        assertEquals(ErrorCode.MEDIA_NOT_VERIFIED, exception.errorCode)
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
