package com.nugusauce.application.member

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.application.recipe.RecipeResult
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.media.MediaAssetRepository
import com.nugusauce.domain.media.MediaAssetStatus
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
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
import java.util.Locale

@Service
@Transactional
class MemberService(
    private val memberRepository: MemberRepository,
    private val sauceRecipeRepository: SauceRecipeRepository,
    private val recipeFavoriteRepository: RecipeFavoriteRepository,
    private val recipeReviewRepository: RecipeReviewRepository,
    private val imageUrlResolver: ImageUrlResolver,
    private val mediaAssetRepository: MediaAssetRepository,
    private val imageStoragePort: ImageStoragePort,
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
        val reviewTagsByRecipeId = loadReviewTagCounts((recipes + favoriteRecipes).map { it.id })
        return MemberResult.publicProfile(
            member = member,
            recipes = summarizeWithReviewTags(recipes, reviewTagsByRecipeId),
            favoriteRecipes = summarizeWithReviewTags(favoriteRecipes, reviewTagsByRecipeId),
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

    private fun findMember(memberId: Long): Member {
        return memberRepository.findById(memberId).orElseThrow {
            BusinessException(ErrorCode.USER_NOT_FOUND)
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

        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(
                object : TransactionSynchronization {
                    override fun afterCommit() {
                        deleteReplacedProfileImage(assetId, providerKey)
                    }
                }
            )
            return
        }

        deleteReplacedProfileImage(assetId, providerKey)
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

    private fun summarizeWithReviewTags(
        recipes: List<SauceRecipe>,
        reviewTagsByRecipeId: Map<Long, List<RecipeResult.ReviewTagCount>>
    ): List<RecipeResult.RecipeSummary> {
        return recipes.map { recipe ->
            RecipeResult.summary(
                recipe,
                reviewTagsByRecipeId[recipe.id].orEmpty(),
                imageUrl = imageUrlResolver.recipeImageUrl(recipe)
            )
        }
    }

    private fun loadReviewTagCounts(recipeIds: Collection<Long>): Map<Long, List<RecipeResult.ReviewTagCount>> {
        if (recipeIds.isEmpty()) {
            return emptyMap()
        }
        return recipeReviewRepository.countTasteTagsByRecipeIds(recipeIds.toSet())
            .groupBy { it.recipeId }
            .mapValues { (_, counts) ->
                counts
                    .map(RecipeResult::reviewTagCount)
                    .sortedWith(
                        compareByDescending<RecipeResult.ReviewTagCount> { it.count }
                            .thenBy { it.name }
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
