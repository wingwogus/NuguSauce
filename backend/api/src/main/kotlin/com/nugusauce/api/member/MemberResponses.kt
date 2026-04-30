package com.nugusauce.api.member

import com.nugusauce.application.member.MemberResult
import com.nugusauce.api.recipe.RecipeResponses

object MemberResponses {
    data class MeResponse(
        val id: Long,
        val nickname: String?,
        val displayName: String,
        val profileImageUrl: String?,
        val profileSetupRequired: Boolean
    ) {
        companion object {
            fun from(result: MemberResult.Me): MeResponse {
                return MeResponse(
                    id = result.id,
                    nickname = result.nickname,
                    displayName = result.displayName,
                    profileImageUrl = result.profileImageUrl,
                    profileSetupRequired = result.profileSetupRequired
                )
            }
        }
    }

    data class PublicProfileResponse(
        val id: Long,
        val nickname: String?,
        val displayName: String,
        val profileImageUrl: String?,
        val profileSetupRequired: Boolean,
        val recipes: List<RecipeResponses.RecipeSummaryResponse>,
        val favoriteRecipes: List<RecipeResponses.RecipeSummaryResponse>
    ) {
        companion object {
            fun from(result: MemberResult.PublicProfile): PublicProfileResponse {
                return PublicProfileResponse(
                    id = result.id,
                    nickname = result.nickname,
                    displayName = result.displayName,
                    profileImageUrl = result.profileImageUrl,
                    profileSetupRequired = result.profileSetupRequired,
                    recipes = result.recipes.map(RecipeResponses.RecipeSummaryResponse::from),
                    favoriteRecipes = result.favoriteRecipes.map(RecipeResponses.RecipeSummaryResponse::from)
                )
            }
        }
    }
}
