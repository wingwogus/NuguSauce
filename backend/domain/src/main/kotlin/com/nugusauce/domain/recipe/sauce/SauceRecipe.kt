package com.nugusauce.domain.recipe.sauce

import com.nugusauce.domain.member.Member
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.recipe.ingredient.Ingredient
import com.nugusauce.domain.recipe.ingredient.RecipeIngredient
import com.nugusauce.domain.recipe.tag.RecipeTag
import jakarta.persistence.CascadeType
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.Index
import jakarta.persistence.JoinColumn
import jakarta.persistence.JoinTable
import jakarta.persistence.ManyToMany
import jakarta.persistence.ManyToOne
import jakarta.persistence.OneToMany
import jakarta.persistence.Table
import java.math.BigDecimal
import java.time.Instant

@Entity
@Table(
    name = "sauce_recipe",
    indexes = [
        Index(
            name = "idx_sauce_recipe_visibility_popularity",
            columnList = "visibility, review_count, favorite_count"
        )
    ]
)
class SauceRecipe(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @Column(nullable = false, length = 120)
    val title: String,

    @Column(nullable = false, length = 1000)
    val description: String,

    @Column(nullable = false)
    val spiceLevel: Int,

    @Column(nullable = false)
    val richnessLevel: Int,

    @Column(nullable = true, length = 2048)
    val imageUrl: String? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "image_asset_id", nullable = true)
    val imageAsset: MediaAsset? = null,

    @Column(nullable = true, length = 1000)
    val tips: String? = null,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    val authorType: RecipeAuthorType,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id", nullable = true)
    val author: Member? = null,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    var visibility: RecipeVisibility = RecipeVisibility.VISIBLE,

    @Column(nullable = false)
    var averageRating: Double = 0.0,

    @Column(nullable = false)
    var reviewCount: Int = 0,

    @Column(nullable = false)
    var favoriteCount: Int = 0,

    @Column(nullable = true)
    var lastReviewedAt: Instant? = null,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @OneToMany(mappedBy = "recipe", cascade = [CascadeType.ALL], orphanRemoval = true)
    val ingredients: MutableList<RecipeIngredient> = mutableListOf(),

    @ManyToMany
    @JoinTable(
        name = "sauce_recipe_tag",
        joinColumns = [JoinColumn(name = "recipe_id")],
        inverseJoinColumns = [JoinColumn(name = "tag_id")]
    )
    val tags: MutableSet<RecipeTag> = linkedSetOf()
) {
    init {
        require(title.isNotBlank()) { "recipe title must not be blank" }
        require(description.isNotBlank()) { "recipe description must not be blank" }
        require(spiceLevel in 0..5) { "spice level must be between 0 and 5" }
        require(richnessLevel in 0..5) { "richness level must be between 0 and 5" }
        require(authorType != RecipeAuthorType.USER || author != null) {
            "user recipes must have an author"
        }
    }

    fun addIngredient(
        ingredient: Ingredient,
        amount: BigDecimal?,
        unit: String?,
        ratio: BigDecimal?
    ) {
        require(amount != null || ratio != null) {
            "ingredient amount or ratio is required"
        }
        amount?.let {
            require(it > BigDecimal.ZERO) { "ingredient amount must be positive" }
        }
        ratio?.let {
            require(it > BigDecimal.ZERO) { "ingredient ratio must be positive" }
        }

        ingredients.add(
            RecipeIngredient(
                recipe = this,
                ingredient = ingredient,
                amount = amount,
                unit = unit,
                ratio = ratio
            )
        )
        touch()
    }

    fun addTag(tag: RecipeTag) {
        require(authorType != RecipeAuthorType.USER) {
            "user recipes cannot select taste tags"
        }
        tags.add(tag)
        touch()
    }

    fun recordReview(rating: Int, reviewedAt: Instant = Instant.now()) {
        require(rating in 1..5) { "rating must be between 1 and 5" }

        val total = averageRating * reviewCount + rating
        reviewCount += 1
        averageRating = total / reviewCount
        lastReviewedAt = reviewedAt
        touch(reviewedAt)
    }

    fun recordFavorite(favoritedAt: Instant = Instant.now()) {
        favoriteCount += 1
        touch(favoritedAt)
    }

    fun removeFavorite(removedAt: Instant = Instant.now()) {
        favoriteCount = (favoriteCount - 1).coerceAtLeast(0)
        touch(removedAt)
    }

    fun changeVisibility(nextVisibility: RecipeVisibility) {
        visibility = nextVisibility
        touch()
    }

    private fun touch(at: Instant = Instant.now()) {
        updatedAt = at
    }
}
