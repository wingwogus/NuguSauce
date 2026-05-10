package com.nugusauce.domain.recipe.review

import com.nugusauce.domain.member.Member
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import jakarta.persistence.UniqueConstraint
import java.time.Instant

@Entity
@Table(
    name = "recipe_review",
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_recipe_review_recipe_author",
            columnNames = ["recipe_id", "author_id"]
        )
    ]
)
class RecipeReview(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "recipe_id", nullable = false)
    val recipe: SauceRecipe,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "author_id", nullable = false)
    val author: Member,

    @Column(nullable = false)
    val rating: Int,

    @Column(nullable = true, length = 1000)
    val text: String? = null,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),
) {
    init {
        require(rating in 1..5) { "rating must be between 1 and 5" }
    }
}
