package com.nugusauce.application.member

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.recipe.RecipeResult
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.Locale

@Service
@Transactional
class MemberService(
    private val memberRepository: MemberRepository,
    private val sauceRecipeRepository: SauceRecipeRepository,
    private val recipeFavoriteRepository: RecipeFavoriteRepository,
    private val recipeReviewRepository: RecipeReviewRepository
) {
    fun getMe(memberId: Long): MemberResult.Me {
        return MemberResult.me(findMember(memberId))
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
            favoriteRecipes = summarizeWithReviewTags(favoriteRecipes, reviewTagsByRecipeId)
        )
    }

    fun updateMe(command: MemberCommand.UpdateMe): MemberResult.Me {
        val member = findMember(command.memberId)
        val nickname = normalizeNickname(command.nickname)

        if (member.nickname != nickname && memberRepository.existsByNicknameAndIdNot(nickname, member.id)) {
            throw BusinessException(ErrorCode.DUPLICATE_NICKNAME)
        }

        try {
            member.nickname = nickname
            memberRepository.saveAndFlush(member)
        } catch (e: DataIntegrityViolationException) {
            if (isNicknameUniqueViolation(e)) {
                throw BusinessException(
                    ErrorCode.DUPLICATE_NICKNAME,
                    detail = mapOf("field" to "nickname")
                )
            }
            throw e
        }
        return MemberResult.me(member)
    }

    private fun findMember(memberId: Long): Member {
        return memberRepository.findById(memberId).orElseThrow {
            BusinessException(ErrorCode.USER_NOT_FOUND)
        }
    }

    private fun summarizeWithReviewTags(
        recipes: List<SauceRecipe>,
        reviewTagsByRecipeId: Map<Long, List<RecipeResult.ReviewTagCount>>
    ): List<RecipeResult.RecipeSummary> {
        return recipes.map { recipe ->
            RecipeResult.summary(recipe, reviewTagsByRecipeId[recipe.id].orEmpty())
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
