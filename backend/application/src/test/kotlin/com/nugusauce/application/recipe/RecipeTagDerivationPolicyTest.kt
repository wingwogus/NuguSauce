package com.nugusauce.application.recipe

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import java.math.BigDecimal

class RecipeTagDerivationPolicyTest {
    private val policy = RecipeTagDerivationPolicy()

    @Test
    fun `derive returns top three ingredient ratio tags in canonical tie order`() {
        val tags = policy.derive(
            listOf(
                signal("땅콩소스", ratio = "3"),
                signal("스위트 칠리소스", ratio = "2"),
                signal("간장", ratio = "2"),
                signal("다진 마늘", ratio = "1"),
                signal("고수", ratio = "1"),
                signal("식초", ratio = "1")
            )
        )

        assertEquals(listOf("고소함", "매콤함", "달달함"), tags)
    }

    @Test
    fun `derive uses amount and unit weights when ratio is absent`() {
        val tags = policy.derive(
            listOf(
                signal("마라소스", amount = "2", unit = "스푼"),
                signal("땅콩소스", amount = "1", unit = "티스푼")
            )
        )

        assertEquals(listOf("마라강함"), tags)
    }

    private fun signal(
        name: String,
        amount: String? = null,
        unit: String? = null,
        ratio: String? = null
    ): RecipeTagDerivationPolicy.IngredientSignal {
        return RecipeTagDerivationPolicy.IngredientSignal(
            name = name,
            category = null,
            amount = amount?.let(::BigDecimal),
            unit = unit,
            ratio = ratio?.let(::BigDecimal)
        )
    }
}
