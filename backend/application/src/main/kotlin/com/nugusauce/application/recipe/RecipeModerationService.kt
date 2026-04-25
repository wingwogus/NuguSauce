package com.nugusauce.application.recipe

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.report.RecipeReport
import com.nugusauce.domain.recipe.report.RecipeReportRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class RecipeModerationService(
    private val memberRepository: MemberRepository,
    private val sauceRecipeRepository: SauceRecipeRepository,
    private val recipeReportRepository: RecipeReportRepository
) {
    fun report(command: RecipeCommand.CreateReport): RecipeResult.ReportItem {
        if (command.reason.isBlank()) {
            throw BusinessException(ErrorCode.INVALID_INPUT)
        }

        val reporter = findMember(command.reporterId)
        val recipe = findVisibleRecipe(command.recipeId)
        if (recipeReportRepository.existsByRecipeAndReporter(command.recipeId, command.reporterId)) {
            throw BusinessException(ErrorCode.DUPLICATE_REPORT)
        }

        val report = RecipeReport(
            recipe = recipe,
            reporter = reporter,
            reason = command.reason.trim()
        )
        return RecipeResult.report(recipeReportRepository.save(report))
    }

    fun updateVisibility(command: RecipeCommand.UpdateVisibility): RecipeResult.RecipeDetail {
        val recipe = sauceRecipeRepository.findById(command.recipeId).orElseThrow {
            BusinessException(ErrorCode.RECIPE_NOT_FOUND)
        }
        recipe.changeVisibility(command.visibility.toDomainVisibility())
        return RecipeResult.detail(sauceRecipeRepository.save(recipe))
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

    private fun RecipeCommand.Visibility.toDomainVisibility(): RecipeVisibility {
        return when (this) {
            RecipeCommand.Visibility.VISIBLE -> RecipeVisibility.VISIBLE
            RecipeCommand.Visibility.HIDDEN -> RecipeVisibility.HIDDEN
        }
    }
}
