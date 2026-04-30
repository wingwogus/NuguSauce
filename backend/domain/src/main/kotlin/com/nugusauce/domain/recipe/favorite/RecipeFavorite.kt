package com.nugusauce.domain.recipe.favorite

import com.nugusauce.domain.member.Member
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.Index
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import jakarta.persistence.UniqueConstraint
import java.time.Instant

@Entity
@Table(
    name = "recipe_favorite",
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_recipe_favorite_recipe_member",
            columnNames = ["recipe_id", "member_id"]
        )
    ],
    indexes = [
        Index(
            name = "idx_recipe_favorite_recipe_created_at",
            columnList = "recipe_id, created_at"
        ),
        Index(
            name = "idx_recipe_favorite_member_created_at",
            columnList = "member_id, created_at"
        )
    ]
)
class RecipeFavorite(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "recipe_id", nullable = false)
    val recipe: SauceRecipe,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)
