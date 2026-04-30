package com.nugusauce.application.media

import com.nugusauce.domain.member.Member
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import org.springframework.stereotype.Component

@Component
class ImageUrlResolver(
    private val imageStoragePort: ImageStoragePort
) {
    fun recipeImageUrl(recipe: SauceRecipe): String? {
        return recipe.imageAsset?.providerKey?.let(imageStoragePort::displayUrl) ?: recipe.imageUrl
    }

    fun memberProfileImageUrl(member: Member): String? {
        return member.profileImageAsset?.providerKey?.let(imageStoragePort::displayUrl)
    }
}
