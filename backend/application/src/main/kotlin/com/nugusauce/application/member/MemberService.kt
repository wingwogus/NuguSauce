package com.nugusauce.application.member

import com.nugusauce.application.auth.AppleTokenPort
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.application.recipe.RecipeResult
import com.nugusauce.application.redis.RefreshTokenRepository
import com.nugusauce.application.security.AppleRefreshTokenCipher
import com.nugusauce.domain.consent.MemberPolicyAcceptanceRepository
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.media.MediaAssetRepository
import com.nugusauce.domain.media.MediaAssetStatus
import com.nugusauce.domain.member.AuthProvider
import com.nugusauce.domain.member.ExternalIdentity
import com.nugusauce.domain.member.ExternalIdentityRepository
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.report.RecipeReportRepository
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import mu.KotlinLogging
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.stereotype.Service
import org.springframework.transaction.PlatformTransactionManager
import org.springframework.transaction.TransactionDefinition
import org.springframework.transaction.annotation.Transactional
import org.springframework.transaction.support.TransactionSynchronization
import org.springframework.transaction.support.TransactionSynchronizationManager
import org.springframework.transaction.support.TransactionTemplate
import java.time.Instant
import java.util.Locale

@Service
@Transactional
class MemberService(
    private val memberRepository: MemberRepository,
    private val sauceRecipeRepository: SauceRecipeRepository,
    private val recipeFavoriteRepository: RecipeFavoriteRepository,
    private val recipeReviewRepository: RecipeReviewRepository,
    private val recipeReportRepository: RecipeReportRepository,
    private val externalIdentityRepository: ExternalIdentityRepository,
    private val memberPolicyAcceptanceRepository: MemberPolicyAcceptanceRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val imageUrlResolver: ImageUrlResolver,
    private val mediaAssetRepository: MediaAssetRepository,
    private val imageStoragePort: ImageStoragePort,
    private val appleTokenPort: AppleTokenPort,
    private val appleRefreshTokenCipher: AppleRefreshTokenCipher,
    transactionManager: PlatformTransactionManager
) {
    private val profileImageCleanupTransaction = TransactionTemplate(transactionManager).apply {
        propagationBehavior = TransactionDefinition.PROPAGATION_REQUIRES_NEW
    }

    fun getMe(memberId: Long): MemberResult.Me {
        val member = findMember(memberId)
        return MemberResult.me(member, imageUrlResolver.memberProfileImageUrl(member))
    }

    fun getPublicProfile(memberId: Long): MemberResult.PublicProfile {
        val member = findMember(memberId)
        val recipes = sauceRecipeRepository.findAllByAuthorIdAndVisibilityOrderByCreatedAtDesc(
            memberId,
            RecipeVisibility.VISIBLE
        )
        val favoriteRecipes = recipeFavoriteRepository.findAllByMemberIdOrderByCreatedAtDesc(memberId)
            .map { it.recipe }
            .filter { it.visibility == RecipeVisibility.VISIBLE }
        return MemberResult.publicProfile(
            member = member,
            recipes = summarizeRecipes(recipes),
            favoriteRecipes = summarizeRecipes(favoriteRecipes),
            profileImageUrl = imageUrlResolver.memberProfileImageUrl(member)
        )
    }

    fun updateMe(command: MemberCommand.UpdateMe): MemberResult.Me {
        val member = findMember(command.memberId)
        val nickname = normalizeNickname(command.nickname)
        val profileImage = command.profileImageId?.let { findAttachableProfileImage(it, member) }

        if (member.nickname != nickname && memberRepository.existsByNicknameAndIdNot(nickname, member.id)) {
            throw BusinessException(ErrorCode.DUPLICATE_NICKNAME)
        }

        var previousProfileImageToCleanup: MediaAsset? = null

        try {
            member.nickname = nickname
            if (profileImage != null) {
                previousProfileImageToCleanup = member.profileImageAsset
                    ?.takeIf { it.id != profileImage.id }
                previousProfileImageToCleanup?.detachFromProfile(member.id)
                profileImage.attachToProfile(member.id)
                member.profileImageAsset = profileImage
            }
            memberRepository.saveAndFlush(member)
            previousProfileImageToCleanup?.let(::deleteReplacedProfileImageAfterCommit)
        } catch (e: DataIntegrityViolationException) {
            if (isNicknameUniqueViolation(e)) {
                throw BusinessException(
                    ErrorCode.DUPLICATE_NICKNAME,
                    detail = mapOf("field" to "nickname")
                )
            }
            throw e
        }
        return MemberResult.me(member, imageUrlResolver.memberProfileImageUrl(member))
    }

    fun deleteMe(memberId: Long) {
        val member = findMember(memberId)
        val externalIdentities = externalIdentityRepository.findAllByMemberId(memberId)
        val appleRefreshTokens = externalIdentities.mapNotNull(::decryptAppleRefreshToken)
        val ownedMediaAssets = mediaAssetRepository.findAllByOwnerId(memberId)
        val ownedMediaProviderKeys = ownedMediaAssets.map { it.providerKey }.distinct()

        val authoredRecipes = sauceRecipeRepository.findAllByAuthorId(memberId)
        authoredRecipes.forEach(::deleteAuthoredRecipeGraph)
        if (authoredRecipes.isNotEmpty()) {
            sauceRecipeRepository.flush()
        }

        deleteMemberReviews(memberId)
        deleteMemberFavorites(memberId)
        deleteMemberReports(memberId)
        deletePolicyAcceptances(memberId)
        externalIdentityRepository.deleteAll(externalIdentities)

        member.profileImageAsset?.detachFromProfile(member.id)
        member.profileImageAsset = null
        memberRepository.saveAndFlush(member)

        if (ownedMediaAssets.isNotEmpty()) {
            mediaAssetRepository.deleteAll(ownedMediaAssets)
            mediaAssetRepository.flush()
        }

        memberRepository.delete(member)
        memberRepository.flush()

        runAfterCommit {
            deleteAccountSideEffects(
                memberId = memberId,
                mediaProviderKeys = ownedMediaProviderKeys,
                appleRefreshTokens = appleRefreshTokens
            )
        }
    }

    private fun findMember(memberId: Long): Member {
        return memberRepository.findById(memberId).orElseThrow {
            BusinessException(ErrorCode.USER_NOT_FOUND)
        }
    }

    private fun deleteAuthoredRecipeGraph(recipe: SauceRecipe) {
        recipe.imageAsset?.detachFromRecipe(recipe.id)
        recipe.imageAsset = null
        recipeReportRepository.deleteAll(recipeReportRepository.findAllByRecipeId(recipe.id))
        recipeFavoriteRepository.deleteAll(recipeFavoriteRepository.findAllByRecipeId(recipe.id))
        recipeReviewRepository.deleteAll(recipeReviewRepository.findAllByRecipeId(recipe.id))
        sauceRecipeRepository.delete(recipe)
    }

    private fun deleteMemberReviews(memberId: Long) {
        val reviews = recipeReviewRepository.findAllByAuthorId(memberId)
        if (reviews.isEmpty()) {
            return
        }
        val affectedRecipes = reviews.map { it.recipe }.distinctBy { it.id }
        recipeReviewRepository.deleteAll(reviews)
        recipeReviewRepository.flush()
        affectedRecipes.forEach(::recalculateRatingSummary)
    }

    private fun deleteMemberFavorites(memberId: Long) {
        val favorites = recipeFavoriteRepository.findAllByMemberId(memberId)
        if (favorites.isEmpty()) {
            return
        }
        val affectedRecipes = favorites.map { it.recipe }.distinctBy { it.id }
        recipeFavoriteRepository.deleteAll(favorites)
        recipeFavoriteRepository.flush()
        affectedRecipes.forEach(::recalculateFavoriteCount)
    }

    private fun deleteMemberReports(memberId: Long) {
        val reports = recipeReportRepository.findAllByReporterId(memberId)
        if (reports.isNotEmpty()) {
            recipeReportRepository.deleteAll(reports)
        }
    }

    private fun deletePolicyAcceptances(memberId: Long) {
        val acceptances = memberPolicyAcceptanceRepository.findAllByMemberId(memberId)
        if (acceptances.isNotEmpty()) {
            memberPolicyAcceptanceRepository.deleteAll(acceptances)
        }
    }

    private fun recalculateRatingSummary(recipe: SauceRecipe) {
        val remainingReviews = recipeReviewRepository.findAllByRecipeId(recipe.id)
        recipe.reviewCount = remainingReviews.size
        recipe.averageRating = if (remainingReviews.isEmpty()) {
            0.0
        } else {
            remainingReviews.map { it.rating }.average()
        }
        recipe.lastReviewedAt = remainingReviews.maxOfOrNull { it.createdAt }
        recipe.updatedAt = Instant.now()
        sauceRecipeRepository.save(recipe)
    }

    private fun recalculateFavoriteCount(recipe: SauceRecipe) {
        recipe.favoriteCount = recipeFavoriteRepository.countByRecipeId(recipe.id).toInt()
        recipe.updatedAt = Instant.now()
        sauceRecipeRepository.save(recipe)
    }

    private fun decryptAppleRefreshToken(identity: ExternalIdentity): String? {
        if (identity.provider != AuthProvider.APPLE) {
            return null
        }
        val ciphertext = identity.appleRefreshTokenCiphertext ?: return null
        val nonce = identity.appleRefreshTokenNonce ?: return null
        return try {
            appleRefreshTokenCipher.decrypt(ciphertext, nonce)
        } catch (e: RuntimeException) {
            logger.warn(e) { "Failed to decrypt Apple refresh token for memberId=${identity.member.id}" }
            null
        }
    }

    private fun findAttachableProfileImage(imageId: Long, member: Member): MediaAsset {
        val asset = mediaAssetRepository.findById(imageId).orElseThrow {
            BusinessException(ErrorCode.MEDIA_ASSET_NOT_FOUND)
        }
        if (asset.owner.id != member.id) {
            throw BusinessException(ErrorCode.FORBIDDEN_MEDIA_ASSET)
        }
        if (asset.attachedRecipeId != null ||
            (asset.attachedProfileMemberId != null && asset.attachedProfileMemberId != member.id)
        ) {
            throw BusinessException(ErrorCode.MEDIA_ALREADY_ATTACHED)
        }
        if (asset.status != MediaAssetStatus.VERIFIED &&
            !(asset.status == MediaAssetStatus.ATTACHED && asset.attachedProfileMemberId == member.id)
        ) {
            throw BusinessException(ErrorCode.MEDIA_NOT_VERIFIED)
        }
        return asset
    }

    private fun deleteReplacedProfileImageAfterCommit(asset: MediaAsset) {
        val assetId = asset.id
        val providerKey = asset.providerKey

        runAfterCommit {
            deleteReplacedProfileImage(assetId, providerKey)
        }
    }

    private fun deleteReplacedProfileImage(assetId: Long, providerKey: String) {
        try {
            imageStoragePort.delete(providerKey)
            profileImageCleanupTransaction.executeWithoutResult {
                mediaAssetRepository.deleteById(assetId)
            }
        } catch (e: RuntimeException) {
            logger.warn(e) { "Failed to clean up replaced profile image asset id=$assetId providerKey=$providerKey" }
        }
    }

    private fun runAfterCommit(action: () -> Unit) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(
                object : TransactionSynchronization {
                    override fun afterCommit() {
                        action()
                    }
                }
            )
            return
        }

        action()
    }

    private fun deleteAccountSideEffects(
        memberId: Long,
        mediaProviderKeys: List<String>,
        appleRefreshTokens: List<String>
    ) {
        try {
            refreshTokenRepository.delete(memberId)
        } catch (e: RuntimeException) {
            logger.warn(e) { "Failed to delete refresh token for deleted memberId=$memberId" }
        }

        appleRefreshTokens.forEach { token ->
            try {
                appleTokenPort.revokeRefreshToken(token)
            } catch (e: RuntimeException) {
                logger.warn(e) { "Failed to revoke Apple token for deleted memberId=$memberId" }
            }
        }

        mediaProviderKeys.forEach { providerKey ->
            try {
                imageStoragePort.delete(providerKey)
            } catch (e: RuntimeException) {
                logger.warn(e) { "Failed to delete media provider asset for deleted memberId=$memberId providerKey=$providerKey" }
            }
        }
    }

    private fun summarizeRecipes(recipes: List<SauceRecipe>): List<RecipeResult.RecipeSummary> {
        return recipes.map { recipe ->
            RecipeResult.summary(
                recipe,
                imageUrl = imageUrlResolver.recipeImageUrl(recipe)
            )
        }
    }

    private fun normalizeNickname(rawNickname: String): String {
        val nickname = rawNickname.trim()
        if (!NICKNAME_PATTERN.matches(nickname)) {
            throw BusinessException(
                ErrorCode.INVALID_NICKNAME,
                detail = mapOf(
                    "field" to "nickname",
                    "reason" to "must be 2..20 Korean letters, English letters, digits, or underscores"
                )
            )
        }
        return nickname
    }

    private companion object {
        private val logger = KotlinLogging.logger {}
        private val NICKNAME_PATTERN = Regex("^[가-힣A-Za-z0-9_]{2,20}$")

        private fun isNicknameUniqueViolation(e: DataIntegrityViolationException): Boolean {
            return generateSequence(e as Throwable) { it.cause }
                .mapNotNull { it.message }
                .map { it.lowercase(Locale.ROOT) }
                .any {
                    it.contains("uk_member_nickname") ||
                        (it.contains("member") && it.contains("nickname"))
                }
        }
    }
}
