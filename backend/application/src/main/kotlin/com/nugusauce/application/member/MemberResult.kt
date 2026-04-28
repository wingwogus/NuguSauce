package com.nugusauce.application.member

import com.nugusauce.application.recipe.RecipeResult
import com.nugusauce.domain.member.Member

object MemberResult {
    data class Me(
        val id: Long,
        val nickname: String?,
        val displayName: String,
        val profileSetupRequired: Boolean
    )

    data class PublicProfile(
        val id: Long,
        val nickname: String?,
        val displayName: String,
        val profileSetupRequired: Boolean,
        val recipes: List<RecipeResult.RecipeSummary>,
        val favoriteRecipes: List<RecipeResult.RecipeSummary>
    )

    fun me(member: Member): Me {
        return Me(
            id = member.id,
            nickname = member.nickname,
            displayName = displayName(member),
            profileSetupRequired = member.nickname.isNullOrBlank()
        )
    }

    fun publicProfile(
        member: Member,
        recipes: List<RecipeResult.RecipeSummary>,
        favoriteRecipes: List<RecipeResult.RecipeSummary>
    ): PublicProfile {
        return PublicProfile(
            id = member.id,
            nickname = member.nickname,
            displayName = displayName(member),
            profileSetupRequired = member.nickname.isNullOrBlank(),
            recipes = recipes,
            favoriteRecipes = favoriteRecipes
        )
    }

    fun displayName(member: Member): String {
        return member.nickname ?: "사용자 ${member.id}"
    }
}
