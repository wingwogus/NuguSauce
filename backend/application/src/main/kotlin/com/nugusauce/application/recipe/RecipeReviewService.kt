package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.review.RecipeReview
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Instant

@Service
@Transactional
class RecipeReviewService(
    private val memberRepository: MemberRepository,
    private val sauceRecipeRepository: SauceRecipeRepository,
    private val recipeReviewRepository: RecipeReviewRepository,
    private val imageUrlResolver: ImageUrlResolver
) {
    fun create(command: RecipeCommand.CreateReview): RecipeResult.ReviewItem {
        if (command.rating !in 1..5) {
            throw BusinessException(ErrorCode.INVALID_RATING)
        }

        val author = findMember(command.authorId)
        val recipe = findVisibleRecipe(command.recipeId)
        if (recipeReviewRepository.existsByRecipeAndAuthor(command.recipeId, command.authorId)) {
            throw BusinessException(ErrorCode.DUPLICATE_REVIEW)
        }

        val reviewedAt = Instant.now()
        val review = RecipeReview(
            recipe = recipe,
            author = author,
            rating = command.rating,
            text = command.text?.trim()?.takeIf { it.isNotBlank() },
            createdAt = reviewedAt
        )
        recipe.recordReview(command.rating, reviewedAt)
        sauceRecipeRepository.save(recipe)

        return RecipeResult.review(
            recipeReviewRepository.save(review),
            authorProfileImageUrl = imageUrlResolver.memberProfileImageUrl(author)
        )
    }

    private fun findMember(memberId: Long): Member {
        return memberRepository.findById(memberId).orElseThrow {
            BusinessException(ErrorCode.USER_NOT_FOUND)
        }
    }

    private fun findVisibleRecipe(recipeId: Long): SauceRecipe {
        val recipe = sauceRecipeRepository.findById(recipeId).orElseThrow {
            BusinessException(ErrorCode.RECIPE_NOT_FOUND)
        }
        if (recipe.visibility != RecipeVisibility.VISIBLE) {
            throw BusinessException(ErrorCode.HIDDEN_RECIPE)
        }
        return recipe
    }

}
