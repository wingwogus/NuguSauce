package com.nugusauce.application.recipe

import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import org.springframework.stereotype.Component

@Component
class RecipeImageUrlResolver(
    private val imageStoragePort: ImageStoragePort
) {
    fun imageUrl(recipe: SauceRecipe): String? {
        return recipe.imageAsset?.providerKey?.let(imageStoragePort::displayUrl) ?: recipe.imageUrl
    }
}
