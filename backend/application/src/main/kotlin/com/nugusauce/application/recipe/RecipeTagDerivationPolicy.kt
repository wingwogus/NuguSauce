package com.nugusauce.application.recipe

import org.springframework.stereotype.Component
import java.math.BigDecimal
import java.math.RoundingMode

@Component
class RecipeTagDerivationPolicy {
    val canonicalTagNames: List<String>
        get() = CANONICAL_TAG_NAMES

    data class IngredientSignal(
        val name: String,
        val category: String?,
        val amount: BigDecimal?,
        val unit: String?,
        val ratio: BigDecimal?
    )

    fun derive(inputs: Collection<IngredientSignal>): List<String> {
        val weightedInputs = normalize(inputs)
        if (weightedInputs.isEmpty()) {
            return emptyList()
        }

        val scores = linkedMapOf<String, BigDecimal>()
        weightedInputs.forEach { weighted ->
            for ((tagName, ingredientWeights) in TAG_INGREDIENTS) {
                val weight = ingredientWeights[weighted.signal.name] ?: continue
                scores[tagName] = scores.getOrDefault(tagName, BigDecimal.ZERO) + weighted.share * weight
            }
        }
        addLightTasteScore(scores, weightedInputs)

        return scores
            .filter { (tagName, score) ->
                score >= thresholdFor(tagName)
            }
            .toList()
            .sortedWith(
                compareByDescending<Pair<String, BigDecimal>> { it.second }
                    .thenBy { canonicalOrderIndex(it.first) }
            )
            .take(MAX_TAGS_PER_RECIPE)
            .map { it.first }
    }

    private fun normalize(inputs: Collection<IngredientSignal>): List<WeightedIngredient> {
        val weighted = inputs.mapNotNull { signal ->
            val value = normalizedWeight(signal)
            if (value <= BigDecimal.ZERO) {
                null
            } else {
                signal to value
            }
        }
        val total = weighted.fold(BigDecimal.ZERO) { sum, (_, value) -> sum + value }
        if (total <= BigDecimal.ZERO) {
            return emptyList()
        }

        return weighted.map { (signal, value) ->
            WeightedIngredient(
                signal = signal,
                share = value.divide(total, 8, RoundingMode.HALF_UP)
            )
        }
    }

    private fun normalizedWeight(signal: IngredientSignal): BigDecimal {
        signal.ratio?.takeIf { it > BigDecimal.ZERO }?.let {
            return it
        }
        val amount = signal.amount?.takeIf { it > BigDecimal.ZERO } ?: return BigDecimal.ZERO
        return amount * unitMultiplier(signal.unit)
    }

    private fun unitMultiplier(unit: String?): BigDecimal {
        return when (unit?.trim()) {
            "스푼", "큰술", "비율", null, "" -> BigDecimal.ONE
            "티스푼", "작은술" -> BigDecimal("0.333333")
            "꼬집" -> BigDecimal("0.05")
            else -> BigDecimal.ONE
        }
    }

    private fun addLightTasteScore(
        scores: MutableMap<String, BigDecimal>,
        weightedInputs: List<WeightedIngredient>
    ) {
        val strongScore = listOf("고소함", "매콤함", "달달함", "마라강함")
            .maxOf { scores[it] ?: BigDecimal.ZERO }
        if (strongScore > BigDecimal("0.20")) {
            return
        }

        val lightScore = weightedInputs
            .filter { it.signal.name in LIGHT_INGREDIENTS }
            .fold(BigDecimal.ZERO) { sum, weighted -> sum + weighted.share }
        if (lightScore >= BigDecimal("0.45")) {
            scores["담백함"] = lightScore
        }
    }

    private fun thresholdFor(tagName: String): BigDecimal {
        return when (tagName) {
            "마늘향", "마라강함", "알싸함" -> BigDecimal("0.10")
            "담백함" -> BigDecimal("0.45")
            else -> BigDecimal("0.15")
        }
    }

    private data class WeightedIngredient(
        val signal: IngredientSignal,
        val share: BigDecimal
    )

    companion object {
        const val MAX_TAGS_PER_RECIPE = 3

        val CANONICAL_TAG_NAMES = listOf(
            "고소함",
            "매콤함",
            "달달함",
            "상큼함",
            "마라강함",
            "감칠맛",
            "담백함",
            "마늘향",
            "짭짤함",
            "알싸함",
            "향긋함"
        )

        private val CANONICAL_ORDER = CANONICAL_TAG_NAMES
            .withIndex()
            .associate { it.value to it.index }

        fun canonicalOrderIndex(tagName: String): Int {
            return CANONICAL_ORDER[tagName] ?: Int.MAX_VALUE
        }

        private val TAG_INGREDIENTS: Map<String, Map<String, BigDecimal>> = mapOf(
            "고소함" to weightedIngredients(
                "참기름",
                "땅콩소스",
                "참깨소스",
                "깨",
                "땅콩가루",
                "들깨가루",
                "참깨가루"
            ),
            "매콤함" to weightedIngredients(
                "다진 고추",
                "고추기름",
                "고춧가루",
                "태국 고추",
                "매운 소고기 소스",
                "스위트 칠리소스"
            ),
            "달달함" to weightedIngredients(
                "설탕",
                "연유",
                "스위트 칠리소스",
                "해선장"
            ),
            "상큼함" to weightedIngredients(
                "식초",
                "중국식초",
                "흑식초",
                "레몬즙"
            ),
            "마라강함" to weightedIngredients(
                "마라소스",
                "마라시즈닝",
                "청유 훠궈 소스"
            ),
            "감칠맛" to weightedIngredients(
                "간장",
                "굴소스",
                "버섯소스",
                "볶음 소고기장",
                "매운 소고기 소스",
                "오향 우육",
                "다진 고기",
                "해선장"
            ),
            "마늘향" to weightedIngredients("다진 마늘"),
            "짭짤함" to weightedIngredients(
                "간장",
                "소금",
                "맛소금",
                "굴소스",
                "해선장"
            ),
            "알싸함" to weightedIngredients(
                "와사비",
                "다진 마늘",
                "파",
                "쪽파",
                "대파",
                "양파",
                "다진 고추",
                "태국 고추"
            ),
            "향긋함" to weightedIngredients(
                "고수",
                "파",
                "쪽파",
                "대파",
                "양파"
            )
        )

        private val LIGHT_INGREDIENTS = setOf(
            "간장",
            "식초",
            "중국식초",
            "흑식초",
            "레몬즙",
            "고수",
            "파",
            "쪽파",
            "대파",
            "양파"
        )

        private fun weightedIngredients(vararg names: String): Map<String, BigDecimal> {
            return names.associateWith { BigDecimal.ONE }
        }
    }
}
