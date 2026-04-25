package com.nugusauce.domain.recipe.report

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
    name = "recipe_report",
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_recipe_report_recipe_reporter",
            columnNames = ["recipe_id", "reporter_id"]
        )
    ]
)
class RecipeReport(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "recipe_id", nullable = false)
    val recipe: SauceRecipe,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "reporter_id", nullable = false)
    val reporter: Member,

    @Column(nullable = false, length = 500)
    val reason: String,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
) {
    init {
        require(reason.isNotBlank()) { "report reason must not be blank" }
    }
}
