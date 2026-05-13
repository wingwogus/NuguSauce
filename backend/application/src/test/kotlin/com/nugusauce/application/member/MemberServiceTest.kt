package com.nugusauce.application.member

import com.nugusauce.application.auth.AppleTokenPort
import com.nugusauce.application.auth.AppleTokenResult
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.application.media.MediaResult
import com.nugusauce.application.media.VerifiedUpload
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.application.redis.RefreshTokenRepository
import com.nugusauce.application.security.AppleRefreshTokenCipher
import com.nugusauce.domain.consent.MemberPolicyAcceptanceRepository
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.media.MediaAssetRepository
import com.nugusauce.domain.media.MediaAssetStatus
import com.nugusauce.domain.media.MediaProvider
import com.nugusauce.domain.member.AuthProvider
import com.nugusauce.domain.member.ExternalIdentity
import com.nugusauce.domain.member.ExternalIdentityRepository
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.favorite.RecipeFavorite
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.report.RecipeReportRepository
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.junit.jupiter.MockitoExtension
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.transaction.PlatformTransactionManager
import org.springframework.transaction.TransactionDefinition
import org.springframework.transaction.TransactionStatus
import org.springframework.transaction.support.SimpleTransactionStatus
import java.time.Instant
import java.util.Base64
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

    @Mock
    private lateinit var recipeReportRepository: RecipeReportRepository

    @Mock
    private lateinit var externalIdentityRepository: ExternalIdentityRepository

    @Mock
    private lateinit var memberPolicyAcceptanceRepository: MemberPolicyAcceptanceRepository

    @Mock
    private lateinit var refreshTokenRepository: RefreshTokenRepository

    @Mock
    private lateinit var mediaAssetRepository: MediaAssetRepository

    private lateinit var imageStoragePort: RecordingImageStoragePort
    private lateinit var appleTokenPort: RecordingAppleTokenPort
    private lateinit var appleRefreshTokenCipher: AppleRefreshTokenCipher
    private lateinit var service: MemberService

    @BeforeEach
    fun setUp() {
        imageStoragePort = RecordingImageStoragePort()
        appleTokenPort = RecordingAppleTokenPort()
        appleRefreshTokenCipher = AppleRefreshTokenCipher(TEST_ENCRYPTION_KEY)
        service = MemberService(
            memberRepository,
            sauceRecipeRepository,
            recipeFavoriteRepository,
            recipeReviewRepository,
            recipeReportRepository,
            externalIdentityRepository,
            memberPolicyAcceptanceRepository,
            refreshTokenRepository,
            ImageUrlResolver(imageStoragePort),
            mediaAssetRepository,
            imageStoragePort,
            appleTokenPort,
            appleRefreshTokenCipher,
            TestTransactionManager
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
        val result = service.getPublicProfile(2L)

        assertEquals(2L, result.id)
        assertEquals("마라초보", result.displayName)
        assertFalse(result.profileSetupRequired)
        assertEquals(listOf(10L), result.recipes.map { it.id })
        assertEquals(listOf(11L), result.favoriteRecipes.map { it.id })
        assertEquals(false, result.recipes.first().isFavorite)
        assertEquals(false, result.favoriteRecipes.first().isFavorite)
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
    fun `updateMe attaches verified profile image`() {
        val member = Member(1L, "user@example.test", null)
        val imageAsset = profileImageAsset(id = 20L, owner = member).apply {
            markVerified("image/jpeg", 2000L, width = 800, height = 600)
        }
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(mediaAssetRepository.findById(20L)).thenReturn(Optional.of(imageAsset))
        `when`(memberRepository.existsByNicknameAndIdNot("소스장인", 1L)).thenReturn(false)

        val result = service.updateMe(MemberCommand.UpdateMe(1L, "소스장인", profileImageId = 20L))

        assertEquals(imageAsset, member.profileImageAsset)
        assertEquals(1L, imageAsset.attachedProfileMemberId)
        assertEquals("https://cdn.example.test/nugusauce/images/1/profile-20", result.profileImageUrl)
    }

    @Test
    fun `updateMe deletes previous profile image after replacement`() {
        val member = Member(1L, "user@example.test", null)
        val previousImageAsset = profileImageAsset(id = 10L, owner = member).apply {
            markVerified("image/jpeg", 2000L, width = 800, height = 600)
            attachToProfile(member.id)
        }
        val newImageAsset = profileImageAsset(id = 20L, owner = member).apply {
            markVerified("image/jpeg", 2000L, width = 800, height = 600)
        }
        member.profileImageAsset = previousImageAsset
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(mediaAssetRepository.findById(20L)).thenReturn(Optional.of(newImageAsset))
        `when`(memberRepository.existsByNicknameAndIdNot("소스장인", 1L)).thenReturn(false)

        service.updateMe(MemberCommand.UpdateMe(1L, "소스장인", profileImageId = 20L))

        assertEquals(newImageAsset, member.profileImageAsset)
        assertEquals(null, previousImageAsset.attachedProfileMemberId)
        assertEquals(MediaAssetStatus.VERIFIED, previousImageAsset.status)
        assertEquals(listOf(previousImageAsset.providerKey), imageStoragePort.deletedProviderKeys)
        verify(mediaAssetRepository).deleteById(previousImageAsset.id)
    }

    @Test
    fun `updateMe keeps current profile image when the same image is supplied`() {
        val member = Member(1L, "user@example.test", null)
        val imageAsset = profileImageAsset(id = 20L, owner = member).apply {
            markVerified("image/jpeg", 2000L, width = 800, height = 600)
            attachToProfile(member.id)
        }
        member.profileImageAsset = imageAsset
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(mediaAssetRepository.findById(20L)).thenReturn(Optional.of(imageAsset))
        `when`(memberRepository.existsByNicknameAndIdNot("소스장인", 1L)).thenReturn(false)

        service.updateMe(MemberCommand.UpdateMe(1L, "소스장인", profileImageId = 20L))

        assertEquals(imageAsset, member.profileImageAsset)
        assertTrue(imageStoragePort.deletedProviderKeys.isEmpty())
        verify(mediaAssetRepository, never()).deleteById(imageAsset.id)
    }

    @Test
    fun `updateMe keeps detached previous image row when provider cleanup fails`() {
        val member = Member(1L, "user@example.test", null)
        val previousImageAsset = profileImageAsset(id = 10L, owner = member).apply {
            markVerified("image/jpeg", 2000L, width = 800, height = 600)
            attachToProfile(member.id)
        }
        val newImageAsset = profileImageAsset(id = 20L, owner = member).apply {
            markVerified("image/jpeg", 2000L, width = 800, height = 600)
        }
        member.profileImageAsset = previousImageAsset
        imageStoragePort.failDeletes = true
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(mediaAssetRepository.findById(20L)).thenReturn(Optional.of(newImageAsset))
        `when`(memberRepository.existsByNicknameAndIdNot("소스장인", 1L)).thenReturn(false)

        service.updateMe(MemberCommand.UpdateMe(1L, "소스장인", profileImageId = 20L))

        assertEquals(newImageAsset, member.profileImageAsset)
        assertEquals(null, previousImageAsset.attachedProfileMemberId)
        assertEquals(MediaAssetStatus.VERIFIED, previousImageAsset.status)
        assertEquals(listOf(previousImageAsset.providerKey), imageStoragePort.deleteAttempts)
        assertTrue(imageStoragePort.deletedProviderKeys.isEmpty())
        verify(mediaAssetRepository, never()).deleteById(previousImageAsset.id)
    }

    @Test
    fun `updateMe rejects recipe attached profile image`() {
        val member = Member(1L, "user@example.test", null)
        val imageAsset = profileImageAsset(id = 20L, owner = member).apply {
            markVerified("image/jpeg", 2000L, width = 800, height = 600)
            attachToRecipe(99L)
        }
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(mediaAssetRepository.findById(20L)).thenReturn(Optional.of(imageAsset))

        val exception = assertThrows(BusinessException::class.java) {
            service.updateMe(MemberCommand.UpdateMe(1L, "소스장인", profileImageId = 20L))
        }

        assertEquals(ErrorCode.MEDIA_ALREADY_ATTACHED, exception.errorCode)
    }

    @Test
    fun `updateMe rejects another profile attached image`() {
        val member = Member(1L, "user@example.test", null)
        val imageAsset = profileImageAsset(id = 20L, owner = member).apply {
            markVerified("image/jpeg", 2000L, width = 800, height = 600)
            attachToProfile(2L)
        }
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(mediaAssetRepository.findById(20L)).thenReturn(Optional.of(imageAsset))

        val exception = assertThrows(BusinessException::class.java) {
            service.updateMe(MemberCommand.UpdateMe(1L, "소스장인", profileImageId = 20L))
        }

        assertEquals(ErrorCode.MEDIA_ALREADY_ATTACHED, exception.errorCode)
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

    @Test
    fun `deleteMe deletes member graph and runs external cleanup after commit`() {
        val member = Member(1L, "user@example.test", null, nickname = "소스장인")
        val profileImage = profileImageAsset(id = 10L, owner = member).apply {
            markVerified("image/jpeg", 2000L, width = 800, height = 600)
            attachToProfile(member.id)
        }
        val recipeImage = profileImageAsset(id = 20L, owner = member).apply {
            markVerified("image/jpeg", 2000L, width = 800, height = 600)
            attachToRecipe(100L)
        }
        val authoredRecipe = recipe(id = 100L, author = member).apply {
            imageAsset = recipeImage
        }
        val appleIdentity = ExternalIdentity(
            member = member,
            provider = AuthProvider.APPLE,
            providerSubject = "apple-subject",
            emailAtLinkTime = member.email
        )
        val encrypted = appleRefreshTokenCipher.encrypt("apple-refresh-token")
        appleIdentity.storeAppleRefreshToken(encrypted.ciphertext, encrypted.nonce)
        member.profileImageAsset = profileImage

        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(externalIdentityRepository.findAllByMemberId(1L)).thenReturn(listOf(appleIdentity))
        `when`(mediaAssetRepository.findAllByOwnerId(1L)).thenReturn(listOf(profileImage, recipeImage))
        `when`(sauceRecipeRepository.findAllByAuthorId(1L)).thenReturn(listOf(authoredRecipe))
        `when`(recipeReportRepository.findAllByRecipeId(100L)).thenReturn(emptyList())
        `when`(recipeFavoriteRepository.findAllByRecipeId(100L)).thenReturn(emptyList())
        `when`(recipeReviewRepository.findAllByRecipeId(100L)).thenReturn(emptyList())
        `when`(recipeReviewRepository.findAllByAuthorId(1L)).thenReturn(emptyList())
        `when`(recipeFavoriteRepository.findAllByMemberId(1L)).thenReturn(emptyList())
        `when`(recipeReportRepository.findAllByReporterId(1L)).thenReturn(emptyList())
        `when`(memberPolicyAcceptanceRepository.findAllByMemberId(1L)).thenReturn(emptyList())

        service.deleteMe(1L)

        assertNull(member.profileImageAsset)
        assertNull(profileImage.attachedProfileMemberId)
        assertNull(authoredRecipe.imageAsset)
        assertNull(recipeImage.attachedRecipeId)
        assertEquals(
            listOf(profileImage.providerKey, recipeImage.providerKey),
            imageStoragePort.deletedProviderKeys
        )
        assertEquals(listOf("apple-refresh-token"), appleTokenPort.revokedRefreshTokens)
        verify(refreshTokenRepository).delete(1L)
        verify(externalIdentityRepository).deleteAll(listOf(appleIdentity))
        verify(mediaAssetRepository).deleteAll(listOf(profileImage, recipeImage))
        verify(sauceRecipeRepository).delete(authoredRecipe)
        verify(memberRepository).delete(member)
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
            author = author,
            visibility = visibility
        )
    }

    private fun profileImageAsset(id: Long, owner: Member): MediaAsset {
        return MediaAsset(
            id = id,
            owner = owner,
            provider = MediaProvider.CLOUDINARY,
            providerKey = "nugusauce/images/${owner.id}/profile-$id",
            contentType = "image/jpeg",
            byteSize = 2000L
        )
    }

    private class RecordingImageStoragePort : ImageStoragePort {
        val deletedProviderKeys = mutableListOf<String>()
        val deleteAttempts = mutableListOf<String>()
        var failDeletes = false

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
            deleteAttempts.add(providerKey)
            if (failDeletes) {
                throw IllegalStateException("delete failed")
            }
            deletedProviderKeys.add(providerKey)
        }
    }

    private object TestTransactionManager : PlatformTransactionManager {
        override fun getTransaction(definition: TransactionDefinition?): TransactionStatus {
            return SimpleTransactionStatus()
        }

        override fun commit(status: TransactionStatus) = Unit

        override fun rollback(status: TransactionStatus) = Unit
    }

    private class RecordingAppleTokenPort : AppleTokenPort {
        val revokedRefreshTokens = mutableListOf<String>()

        override fun exchangeAuthorizationCode(authorizationCode: String): AppleTokenResult? {
            throw UnsupportedOperationException()
        }

        override fun revokeRefreshToken(refreshToken: String) {
            revokedRefreshTokens.add(refreshToken)
        }
    }

    private companion object {
        private val TEST_ENCRYPTION_KEY = Base64.getEncoder()
            .encodeToString(ByteArray(32) { (it + 1).toByte() })
    }
}
