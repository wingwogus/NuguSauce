package com.nugusauce.api.fixture

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import kotlin.io.path.exists

class NuguSauceFixtureContractTest {
    private val fixture = loadFixture()
    private val allowedIngredientCategories = setOf(
        "sauce_paste",
        "oil",
        "vinegar_citrus",
        "fresh_aromatic",
        "dry_seasoning",
        "sweet_dairy",
        "topping_seed",
        "protein",
        "other"
    )

    @Test
    fun `curated recipes include visible celebrity sauce set and hidden sample`() {
        val curatedRecipes = fixture.requiredArray("recipes_curated")
        val visibleRecipes = curatedRecipes.filter { it.requiredText("visibility") == "VISIBLE" }
        val hiddenRecipes = curatedRecipes.filter { it.requiredText("visibility") == "HIDDEN" }

        assertTrue(visibleRecipes.size >= 8, "Expected at least 8 visible celebrity curated recipes")
        assertTrue(hiddenRecipes.isNotEmpty(), "Expected at least one hidden curated recipe")
    }

    @Test
    fun `fixture ids are unique within each group`() {
        listOf(
            "users",
            "ingredients_master",
            "tags",
            "recipes_curated",
            "recipes_user_generated",
            "reviews",
            "reports",
            "favorites"
        ).forEach { groupName ->
            val ids = fixture.requiredArray(groupName).map { it.requiredLong("id") }

            assertEquals(ids.size, ids.toSet().size, "Duplicate IDs in $groupName")
        }
    }

    @Test
    fun `ingredient categories are physical groupings`() {
        fixture.requiredArray("ingredients_master").forEach { ingredient ->
            val category = ingredient.requiredText("category")

            assertTrue(
                category in allowedIngredientCategories,
                "Unsupported ingredient category $category for ${ingredient.requiredText("name")}"
            )
        }
    }

    @Test
    fun `recipe ingredient and tag references point at master data`() {
        val ingredientIds = fixture.requiredArray("ingredients_master")
            .map { it.requiredLong("id") }
            .toSet()
        val tagIds = fixture.requiredArray("tags")
            .map { it.requiredLong("id") }
            .toSet()

        fixture.allRecipes().forEach { recipe ->
            recipe.requiredArray("ingredients").forEach { ingredient ->
                assertTrue(
                    ingredient.requiredLong("ingredientId") in ingredientIds,
                    "Unknown ingredient ${ingredient.requiredLong("ingredientId")} in ${recipe.requiredText("title")}"
                )
                assertTrue(
                    ingredient.requiredText("unit").isNotBlank(),
                    "Blank ingredient unit in ${recipe.requiredText("title")}"
                )
            }

            recipe.optionalArray("tagIds").forEach { tagId ->
                assertTrue(
                    tagId.asLong() in tagIds,
                    "Unknown tag ${tagId.asLong()} in ${recipe.requiredText("title")}"
                )
            }
        }
    }

    @Test
    fun `user generated recipes do not contain author selected taste classification`() {
        fixture.requiredArray("recipes_user_generated").forEach { recipe ->
            assertFalse(recipe.has("spiceLevel"), "User recipe must not carry author-selected spiceLevel")
            assertFalse(recipe.has("richnessLevel"), "User recipe must not carry author-selected richnessLevel")
            assertFalse(recipe.has("tagIds"), "User recipe must not carry author-selected tagIds")
        }
    }

    @Test
    fun `reviews reports and favorites reference existing recipes and users`() {
        val recipeIds = fixture.allRecipes()
            .map { it.requiredLong("id") }
            .toSet()
        val userIds = fixture.requiredArray("users")
            .map { it.requiredLong("id") }
            .toSet()

        fixture.requiredArray("reviews").forEach { review ->
            assertTrue(review.requiredLong("recipeId") in recipeIds, "Review references unknown recipe")
            assertTrue(review.requiredLong("authorUserId") in userIds, "Review references unknown user")
        }

        fixture.requiredArray("reports").forEach { report ->
            assertTrue(report.requiredLong("recipeId") in recipeIds, "Report references unknown recipe")
            assertTrue(report.requiredLong("reporterUserId") in userIds, "Report references unknown user")
        }

        fixture.requiredArray("favorites").forEach { favorite ->
            assertTrue(favorite.requiredLong("recipeId") in recipeIds, "Favorite references unknown recipe")
            assertTrue(favorite.requiredLong("memberUserId") in userIds, "Favorite references unknown user")
        }
    }

    private fun JsonNode.allRecipes(): List<JsonNode> {
        return requiredArray("recipes_curated") + requiredArray("recipes_user_generated")
    }

    private fun JsonNode.requiredArray(fieldName: String): List<JsonNode> {
        val value = this[fieldName]
        require(value != null && value.isArray) { "Missing array field: $fieldName" }
        return value.toList()
    }

    private fun JsonNode.optionalArray(fieldName: String): List<JsonNode> {
        val value = this[fieldName] ?: return emptyList()
        require(value.isArray) { "Expected array field: $fieldName" }
        return value.toList()
    }

    private fun JsonNode.requiredLong(fieldName: String): Long {
        val value = this[fieldName]
        require(value != null && value.canConvertToLong()) { "Missing long field: $fieldName" }
        return value.asLong()
    }

    private fun JsonNode.requiredText(fieldName: String): String {
        val value = this[fieldName]
        require(value != null && value.isTextual) { "Missing text field: $fieldName" }
        return value.asText()
    }

    private fun loadFixture(): JsonNode {
        val path = fixturePath()
        require(path.exists()) { "Fixture does not exist: $path" }
        return Files.newBufferedReader(path).use { reader ->
            jacksonObjectMapper().readTree(reader)
        }
    }

    private fun fixturePath(): Path {
        val userDir = Path.of(System.getProperty("user.dir"))
        val candidates = listOf(
            userDir.resolve("../../docs/fixtures/nugusauce-mvp.json").normalize(),
            userDir.resolve("../docs/fixtures/nugusauce-mvp.json").normalize(),
            userDir.resolve("docs/fixtures/nugusauce-mvp.json").normalize()
        )
        return candidates.firstOrNull { it.exists() }
            ?: candidates.first()
    }
}
