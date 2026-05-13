package com.nugusauce.application.member

import com.nugusauce.application.auth.AppleTokenPort
import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.application.media.MediaResult
import com.nugusauce.application.media.VerifiedUpload
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.application.redis.RefreshTokenRepository
import com.nugusauce.application.security.AppleRefreshTokenCipher
import com.nugusauce.domain.consent.MemberPolicyAcceptanceRepository
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.media.MediaAssetRepository
import com.nugusauce.domain.media.MediaProvider
import com.nugusauce.domain.member.ExternalIdentityRepository
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.report.RecipeReportRepository
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mockito.`when`
import org.mockito.Mockito.mock
import org.mockito.Mockito.reset
import org.mockito.Mockito.verify
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.test.context.ContextConfiguration
import org.springframework.test.context.junit.jupiter.SpringExtension
import org.springframework.transaction.TransactionDefinition
import org.springframework.transaction.annotation.EnableTransactionManagement
import org.springframework.transaction.support.AbstractPlatformTransactionManager
import org.springframework.transaction.support.DefaultTransactionStatus
import java.time.Instant
import java.util.Base64
import java.util.Optional

@ExtendWith(SpringExtension::class)
@ContextConfiguration(classes = [MemberServiceTransactionTest.TestConfig::class])
class MemberServiceTransactionTest {
    @Autowired
    private lateinit var service: MemberService

    @Autowired
    private lateinit var memberRepository: MemberRepository

    @Autowired
    private lateinit var mediaAssetRepository: MediaAssetRepository

    @Autowired
    private lateinit var imageStoragePort: RecordingImageStoragePort

    @Autowired
    private lateinit var eventLog: MutableList<String>

    @BeforeEach
    fun setUp() {
        reset(memberRepository, mediaAssetRepository)
        eventLog.clear()
        imageStoragePort.deletedProviderKeys.clear()
    }

    @Test
    fun `updateMe deletes replaced profile image after transaction commit`() {
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

        assertEquals(listOf(previousImageAsset.providerKey), imageStoragePort.deletedProviderKeys)
        verify(mediaAssetRepository).deleteById(previousImageAsset.id)
        assertTrue(eventLog.indexOf("commit:0") < eventLog.indexOf("provider-delete:${previousImageAsset.providerKey}"))
        assertTrue(eventLog.indexOf("provider-delete:${previousImageAsset.providerKey}") < eventLog.indexOf("begin:3"))
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

    @Configuration
    @EnableTransactionManagement(proxyTargetClass = true)
    open class TestConfig {
        @Bean
        open fun eventLog(): MutableList<String> = mutableListOf()

        @Bean
        open fun memberRepository(): MemberRepository = mock(MemberRepository::class.java)

        @Bean
        open fun sauceRecipeRepository(): SauceRecipeRepository = mock(SauceRecipeRepository::class.java)

        @Bean
        open fun recipeFavoriteRepository(): RecipeFavoriteRepository = mock(RecipeFavoriteRepository::class.java)

        @Bean
        open fun recipeReviewRepository(): RecipeReviewRepository = mock(RecipeReviewRepository::class.java)

        @Bean
        open fun recipeReportRepository(): RecipeReportRepository = mock(RecipeReportRepository::class.java)

        @Bean
        open fun externalIdentityRepository(): ExternalIdentityRepository = mock(ExternalIdentityRepository::class.java)

        @Bean
        open fun memberPolicyAcceptanceRepository(): MemberPolicyAcceptanceRepository =
            mock(MemberPolicyAcceptanceRepository::class.java)

        @Bean
        open fun refreshTokenRepository(): RefreshTokenRepository = mock(RefreshTokenRepository::class.java)

        @Bean
        open fun appleTokenPort(): AppleTokenPort = mock(AppleTokenPort::class.java)

        @Bean
        open fun appleRefreshTokenCipher(): AppleRefreshTokenCipher {
            return AppleRefreshTokenCipher(
                Base64.getEncoder().encodeToString(ByteArray(32) { (it + 1).toByte() })
            )
        }

        @Bean
        open fun mediaAssetRepository(): MediaAssetRepository = mock(MediaAssetRepository::class.java)

        @Bean
        open fun imageStoragePort(eventLog: MutableList<String>): RecordingImageStoragePort {
            return RecordingImageStoragePort(eventLog)
        }

        @Bean
        open fun transactionManager(eventLog: MutableList<String>): RecordingTransactionManager {
            return RecordingTransactionManager(eventLog)
        }

        @Bean
        open fun memberService(
            memberRepository: MemberRepository,
            sauceRecipeRepository: SauceRecipeRepository,
            recipeFavoriteRepository: RecipeFavoriteRepository,
            recipeReviewRepository: RecipeReviewRepository,
            recipeReportRepository: RecipeReportRepository,
            externalIdentityRepository: ExternalIdentityRepository,
            memberPolicyAcceptanceRepository: MemberPolicyAcceptanceRepository,
            refreshTokenRepository: RefreshTokenRepository,
            mediaAssetRepository: MediaAssetRepository,
            imageStoragePort: ImageStoragePort,
            appleTokenPort: AppleTokenPort,
            appleRefreshTokenCipher: AppleRefreshTokenCipher,
            transactionManager: RecordingTransactionManager
        ): MemberService {
            return MemberService(
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
                transactionManager
            )
        }
    }

    class RecordingImageStoragePort(
        private val eventLog: MutableList<String>
    ) : ImageStoragePort {
        val deletedProviderKeys = mutableListOf<String>()

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
            eventLog.add("provider-delete:$providerKey")
            deletedProviderKeys.add(providerKey)
        }
    }

    class RecordingTransactionManager(
        private val eventLog: MutableList<String>
    ) : AbstractPlatformTransactionManager() {
        private val propagationStack = ThreadLocal<MutableList<Int>>()

        override fun doGetTransaction(): Any = Any()

        override fun isExistingTransaction(transaction: Any): Boolean {
            return !propagationStack.get().isNullOrEmpty()
        }

        override fun doBegin(transaction: Any, definition: TransactionDefinition) {
            val stack = propagationStack.get() ?: mutableListOf<Int>().also(propagationStack::set)
            stack.add(definition.propagationBehavior)
            eventLog.add("begin:${definition.propagationBehavior}")
        }

        override fun doCommit(status: DefaultTransactionStatus) {
            eventLog.add("commit:${currentPropagation()}")
        }

        override fun doRollback(status: DefaultTransactionStatus) {
            eventLog.add("rollback:${currentPropagation()}")
        }

        override fun doSuspend(transaction: Any): Any {
            val suspended = propagationStack.get()?.toMutableList().orEmpty()
            propagationStack.remove()
            eventLog.add("suspend")
            return suspended
        }

        override fun doResume(transaction: Any?, suspendedResources: Any) {
            @Suppress("UNCHECKED_CAST")
            propagationStack.set((suspendedResources as List<Int>).toMutableList())
            eventLog.add("resume")
        }

        override fun doCleanupAfterCompletion(transaction: Any) {
            val stack = propagationStack.get()
            if (stack.isNullOrEmpty()) {
                propagationStack.remove()
                return
            }
            stack.removeAt(stack.lastIndex)
            if (stack.isEmpty()) {
                propagationStack.remove()
            }
        }

        private fun currentPropagation(): Int {
            return propagationStack.get()?.lastOrNull() ?: TransactionDefinition.PROPAGATION_REQUIRED
        }
    }
}
