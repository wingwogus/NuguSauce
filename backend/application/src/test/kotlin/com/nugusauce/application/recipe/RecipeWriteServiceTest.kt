package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.application.media.MediaResult
import com.nugusauce.application.media.VerifiedUpload
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.media.MediaAssetRepository
import com.nugusauce.domain.media.MediaAssetStatus
import com.nugusauce.domain.media.MediaProvider
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.favorite.RecipeFavorite
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.ingredient.Ingredient
import com.nugusauce.domain.recipe.ingredient.IngredientRepository
import com.nugusauce.domain.recipe.report.RecipeReport
import com.nugusauce.domain.recipe.report.RecipeReportRepository
import com.nugusauce.domain.recipe.review.RecipeReview
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import com.nugusauce.domain.recipe.tag.RecipeTag
import com.nugusauce.domain.recipe.tag.RecipeTagRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito
import org.mockito.Mockito.inOrder
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

    @Mock
    private lateinit var recipeFavoriteRepository: RecipeFavoriteRepository

    @Mock
    private lateinit var recipeReportRepository: RecipeReportRepository

    @Mock
    private lateinit var recipeReviewRepository: RecipeReviewRepository

    @Mock
    private lateinit var recipeTagRepository: RecipeTagRepository

    private lateinit var service: RecipeWriteService

    @BeforeEach
    fun setUp() {
        service = RecipeWriteService(
            memberRepository,
            ingredientRepository,
            sauceRecipeRepository,
            mediaAssetRepository,
            recipeFavoriteRepository,
            recipeReportRepository,
            recipeReviewRepository,
            ImageUrlResolver(TestImageStoragePort),
            recipeTagRepository,
            RecipeTagDerivationPolicy()
        )
    }

    @Test
    fun `create stores user recipe with ingredients`() {
        val member = Member(1L, "user@example.test", null, nickname = "소스장인")
        val ingredient = Ingredient(1L, "참기름", "oil")
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(ingredientRepository.findAllById(setOf(1L))).thenReturn(listOf(ingredient))
        `when`(recipeTagRepository.findAllByNameIn(listOf("고소함"))).thenReturn(listOf(RecipeTag(1L, "고소함")))
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
        assertEquals(listOf("고소함"), result.tags.map { it.name })
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
        `when`(recipeTagRepository.findAllByNameIn(listOf("고소함"))).thenReturn(listOf(RecipeTag(1L, "고소함")))
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

    @Test
    fun `update changes owner recipe composition and replaces image asset`() {
        val member = Member(1L, "user@example.test", null, nickname = "소스장인")
        val oldIngredient = Ingredient(1L, "참기름", "oil")
        val newIngredient = Ingredient(2L, "땅콩소스", "sauce_paste")
        val oldImageAsset = verifiedImageAsset(id = 20L, owner = member, providerKey = "nugusauce/recipes/10/old")
        oldImageAsset.attachToRecipe(10L)
        val newImageAsset = verifiedImageAsset(id = 21L, owner = member, providerKey = "nugusauce/recipes/10/new")
        val recipe = SauceRecipe(
            id = 10L,
            title = "이전 소스",
            description = "이전 설명",
            spiceLevel = 0,
            richnessLevel = 0,
            imageAsset = oldImageAsset,
            author = member
        )
        recipe.addIngredient(oldIngredient, BigDecimal.ONE, "스푼", null)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(sauceRecipeRepository.findByIdAndAuthorId(10L, 1L)).thenReturn(recipe)
        `when`(ingredientRepository.findAllById(setOf(2L))).thenReturn(listOf(newIngredient))
        `when`(mediaAssetRepository.findById(21L)).thenReturn(Optional.of(newImageAsset))
        `when`(recipeTagRepository.findAllByNameIn(listOf("고소함"))).thenReturn(listOf(RecipeTag(1L, "고소함")))

        val result = service.update(
            RecipeCommand.UpdateRecipe(
                authorId = 1L,
                recipeId = 10L,
                title = "  새 소스  ",
                description = "  새 설명  ",
                imageId = 21L,
                tips = "  잘 섞기  ",
                ingredients = listOf(
                    RecipeCommand.IngredientInput(
                        ingredientId = 2L,
                        amount = BigDecimal("2.0"),
                        unit = "비율"
                    )
                )
            )
        )

        assertEquals("새 소스", result.title)
        assertEquals("새 설명", result.description)
        assertEquals("잘 섞기", result.tips)
        assertEquals(listOf("땅콩소스"), result.ingredients.map { it.name })
        assertEquals("https://cdn.example.test/nugusauce/recipes/10/new", result.imageUrl)
        assertNull(oldImageAsset.attachedRecipeId)
        assertEquals(MediaAssetStatus.VERIFIED, oldImageAsset.status)
        assertEquals(10L, newImageAsset.attachedRecipeId)
        assertEquals(MediaAssetStatus.ATTACHED, newImageAsset.status)
    }

    @Test
    fun `update maps non owned recipe to not found`() {
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(Member(1L, "user@example.test", null)))
        `when`(sauceRecipeRepository.findByIdAndAuthorId(10L, 1L)).thenReturn(null)

        val exception = assertThrows(BusinessException::class.java) {
            service.update(
                RecipeCommand.UpdateRecipe(
                    authorId = 1L,
                    recipeId = 10L,
                    title = "내 소스",
                    description = "설명",
                    ingredients = listOf(
                        RecipeCommand.IngredientInput(
                            ingredientId = 1L,
                            amount = BigDecimal.ONE
                        )
                    )
                )
            )
        }

        assertEquals(ErrorCode.RECIPE_NOT_FOUND, exception.errorCode)
    }

    @Test
    fun `update maps hidden owner recipe to not found`() {
        val member = Member(1L, "user@example.test", null)
        val recipe = SauceRecipe(
            id = 10L,
            title = "숨긴 소스",
            description = "설명",
            spiceLevel = 0,
            richnessLevel = 0,
            author = member,
            visibility = RecipeVisibility.HIDDEN
        )
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(sauceRecipeRepository.findByIdAndAuthorId(10L, 1L)).thenReturn(recipe)

        val exception = assertThrows(BusinessException::class.java) {
            service.update(
                RecipeCommand.UpdateRecipe(
                    authorId = 1L,
                    recipeId = 10L,
                    title = "수정",
                    description = "설명",
                    ingredients = listOf(
                        RecipeCommand.IngredientInput(
                            ingredientId = 1L,
                            amount = BigDecimal.ONE
                        )
                    )
                )
            )
        }

        assertEquals(ErrorCode.RECIPE_NOT_FOUND, exception.errorCode)
    }

    @Test
    fun `delete hard deletes owned recipe graph and detaches local image asset`() {
        val member = Member(1L, "user@example.test", null)
        val imageAsset = verifiedImageAsset(id = 20L, owner = member, providerKey = "nugusauce/recipes/10/image")
        imageAsset.attachToRecipe(10L)
        val recipe = SauceRecipe(
            id = 10L,
            title = "내 소스",
            description = "설명",
            spiceLevel = 0,
            richnessLevel = 0,
            imageAsset = imageAsset,
            author = member
        )
        val report = RecipeReport(recipe = recipe, reporter = member, reason = "부적절")
        val favorite = RecipeFavorite(recipe = recipe, member = member)
        val review = RecipeReview(recipe = recipe, author = member, rating = 5)
        `when`(sauceRecipeRepository.findByIdAndAuthorId(10L, 1L)).thenReturn(recipe)
        `when`(recipeReportRepository.findAllByRecipeId(10L)).thenReturn(listOf(report))
        `when`(recipeFavoriteRepository.findAllByRecipeId(10L)).thenReturn(listOf(favorite))
        `when`(recipeReviewRepository.findAllByRecipeId(10L)).thenReturn(listOf(review))

        service.delete(RecipeCommand.DeleteRecipe(authorId = 1L, recipeId = 10L))

        assertNull(recipe.imageAsset)
        assertNull(imageAsset.attachedRecipeId)
        assertEquals(MediaAssetStatus.VERIFIED, imageAsset.status)
        inOrder(recipeReportRepository, recipeFavoriteRepository, recipeReviewRepository, sauceRecipeRepository).also { ordered ->
            ordered.verify(recipeReportRepository).deleteAll(listOf(report))
            ordered.verify(recipeFavoriteRepository).deleteAll(listOf(favorite))
            ordered.verify(recipeReviewRepository).deleteAll(listOf(review))
            ordered.verify(sauceRecipeRepository).delete(recipe)
        }
    }

    @Test
    fun `delete hard deletes legacy hidden owner recipe`() {
        val member = Member(1L, "user@example.test", null)
        val recipe = SauceRecipe(
            id = 10L,
            title = "숨긴 소스",
            description = "설명",
            spiceLevel = 0,
            richnessLevel = 0,
            author = member,
            visibility = RecipeVisibility.HIDDEN
        )
        `when`(sauceRecipeRepository.findByIdAndAuthorId(10L, 1L)).thenReturn(recipe)
        `when`(recipeReportRepository.findAllByRecipeId(10L)).thenReturn(emptyList())
        `when`(recipeFavoriteRepository.findAllByRecipeId(10L)).thenReturn(emptyList())
        `when`(recipeReviewRepository.findAllByRecipeId(10L)).thenReturn(emptyList())

        service.delete(RecipeCommand.DeleteRecipe(authorId = 1L, recipeId = 10L))

        Mockito.verify(sauceRecipeRepository).delete(recipe)
    }

    private fun verifiedImageAsset(id: Long, owner: Member, providerKey: String): MediaAsset {
        return MediaAsset(
            id = id,
            owner = owner,
            provider = MediaProvider.CLOUDINARY,
            providerKey = providerKey,
            contentType = "image/jpeg",
            byteSize = 1000L
        ).apply {
            markVerified(
                contentType = "image/jpeg",
                byteSize = 1000L,
                width = 800,
                height = 600
            )
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

        override fun delete(providerKey: String) {
            throw UnsupportedOperationException()
        }
    }
}
