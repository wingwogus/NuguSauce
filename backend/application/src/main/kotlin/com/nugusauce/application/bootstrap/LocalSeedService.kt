package com.nugusauce.application.bootstrap

import com.nugusauce.domain.consent.PolicyType
import com.nugusauce.domain.consent.PolicyVersion
import com.nugusauce.domain.consent.PolicyVersionRepository
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.favorite.RecipeFavorite
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.ingredient.Ingredient
import com.nugusauce.domain.recipe.ingredient.IngredientRepository
import com.nugusauce.domain.recipe.report.RecipeReport
import com.nugusauce.domain.recipe.report.RecipeReportRepository
import com.nugusauce.domain.recipe.review.RecipeReview
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.RecipeVisibility
import com.nugusauce.domain.recipe.sauce.SauceRecipe
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import com.nugusauce.domain.recipe.tag.RecipeTag
import com.nugusauce.domain.recipe.tag.RecipeTagRepository
import org.slf4j.LoggerFactory
import org.springframework.boot.ApplicationArguments
import org.springframework.boot.ApplicationRunner
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.context.annotation.Profile
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Component
import org.springframework.transaction.annotation.Transactional
import java.math.BigDecimal
import java.time.Instant

@Component
@Profile("local")
@ConditionalOnProperty(name = ["nugusauce.seed.enabled"], havingValue = "true")
class LocalSeedService(
    private val memberRepository: MemberRepository,
    private val policyVersionRepository: PolicyVersionRepository,
    private val ingredientRepository: IngredientRepository,
    private val recipeTagRepository: RecipeTagRepository,
    private val sauceRecipeRepository: SauceRecipeRepository,
    private val recipeReviewRepository: RecipeReviewRepository,
    private val recipeReportRepository: RecipeReportRepository,
    private val recipeFavoriteRepository: RecipeFavoriteRepository,
    private val passwordEncoder: PasswordEncoder
) : ApplicationRunner {
    private val logger = LoggerFactory.getLogger(javaClass)

    @Transactional
    override fun run(args: ApplicationArguments) {
        seedPolicyVersions()

        if (memberRepository.findByEmail(SEED_NORMAL_EMAIL) != null) {
            backfillSeedNicknames()
            logger.info("NuguSauce local seed skipped; seed user already exists")
            return
        }

        val users = seedMembers()
        val ingredients = seedIngredients()
        val tags = seedTags()
        val recipes = seedRecipes(users, ingredients, tags)
        seedReviews(users, recipes, tags)
        seedReports(users, recipes)
        seedFavorites(users, recipes)

        logger.info(
            "NuguSauce local seed created. users={} recipes={}",
            users.size,
            recipes.size
        )
    }

    private fun seedPolicyVersions() {
        val existingPolicyKeys = policyVersionRepository.findAll()
            .map { it.policyType to it.version }
            .toSet()
        val missingPolicies = POLICY_VERSION_SEEDS
            .filterNot { it.policyType to it.version in existingPolicyKeys }
            .map { seed ->
                PolicyVersion(
                    policyType = seed.policyType,
                    version = seed.version,
                    title = seed.title,
                    url = seed.url,
                    required = true,
                    activeFrom = POLICY_ACTIVE_FROM,
                    createdAt = POLICY_ACTIVE_FROM
                )
            }

        if (missingPolicies.isNotEmpty()) {
            policyVersionRepository.saveAll(missingPolicies)
            logger.info("NuguSauce local policy seed created. policies={}", missingPolicies.size)
        }
    }

    private fun seedMembers(): Map<String, Member> {
        return MEMBER_SEEDS.map { seed ->
            Member(
                email = seed.email,
                passwordHash = passwordEncoder.encode("password123"),
                role = seed.role,
                nickname = seed.nickname
            )
        }.let(memberRepository::saveAll)
            .associateBy { it.email }
    }

    private fun backfillSeedNicknames() {
        val members = MEMBER_SEEDS.mapNotNull { seed ->
            memberRepository.findByEmail(seed.email)
                ?.takeIf { it.nickname.isNullOrBlank() }
                ?.apply { nickname = seed.nickname }
        }
        if (members.isNotEmpty()) {
            memberRepository.saveAll(members)
        }
    }

    private fun seedIngredients(): Map<String, Ingredient> {
        val ingredients = INGREDIENT_SEEDS.map { seed ->
            Ingredient(name = seed.name, category = seed.category)
        }
        return ingredientRepository.saveAll(ingredients).associateBy { it.name }
    }

    private fun seedTags(): Map<String, RecipeTag> {
        val tags = TAG_NAMES.map { name -> RecipeTag(name = name) }
        return recipeTagRepository.saveAll(tags).associateBy { it.name }
    }

    private fun seedRecipes(
        users: Map<String, Member>,
        ingredients: Map<String, Ingredient>,
        tags: Map<String, RecipeTag>
    ): Map<String, SauceRecipe> {
        val recipes = RECIPE_SEEDS.map { seed ->
            SauceRecipe(
                title = seed.title,
                description = seed.description,
                spiceLevel = seed.spiceLevel,
                richnessLevel = seed.richnessLevel,
                author = seed.authorEmail?.let(users::getValue),
                visibility = seed.visibility
            ).apply {
                seed.ingredients.forEach { ingredient ->
                    addIngredient(
                        ingredients.getValue(ingredient.name),
                        BigDecimal(ingredient.amount),
                        "스푼",
                        null
                    )
                }
                if (seed.authorEmail == null) {
                    seed.tagNames.map(tags::getValue).forEach(::addTag)
                }
            }
        }

        return sauceRecipeRepository.saveAll(recipes)
            .associateBy { it.title }
    }

    private fun seedReviews(
        users: Map<String, Member>,
        recipes: Map<String, SauceRecipe>,
        tags: Map<String, RecipeTag>
    ) {
        val reviews = listOf(
            ReviewSeed(SEED_NORMAL_EMAIL, "건희 소스 오리지널", 5, "단짠 균형이 좋아서 계속 손이 감", listOf("고소함", "유명조합")),
            ReviewSeed("reviewer@example.test", "건희 소스 오리지널", 4, "고소하지만 살짝 더 매워도 좋음", listOf("고소함", "매콤함")),
            ReviewSeed("reviewer@example.test", "건희 소스 2025 버전", 5, "감칠맛이 더 진한 버전", listOf("고소함", "감칠맛")),
            ReviewSeed(SEED_NORMAL_EMAIL, "마크 소스", 4, "간장과 땅콩 베이스가 묵직함", listOf("고소함", "감칠맛"))
        ).map { seed ->
            val recipe = recipes.getValue(seed.recipeTitle)
            recipe.recordReview(seed.rating)
            RecipeReview(
                recipe = recipe,
                author = users.getValue(seed.authorEmail),
                rating = seed.rating,
                text = seed.text
            ).apply {
                seed.tagNames.map(tags::getValue).forEach(tasteTags::add)
            }
        }

        sauceRecipeRepository.saveAll(recipes.values)
        recipeReviewRepository.saveAll(reviews)
    }

    private fun seedReports(
        users: Map<String, Member>,
        recipes: Map<String, SauceRecipe>
    ) {
        recipeReportRepository.save(
            RecipeReport(
                recipe = recipes.getValue("숨김 처리된 샘플"),
                reporter = users.getValue(SEED_NORMAL_EMAIL),
                reason = "부적절한 내용"
            )
        )
    }

    private fun seedFavorites(
        users: Map<String, Member>,
        recipes: Map<String, SauceRecipe>
    ) {
        val favoriteSeeds = listOf(
            "건희 소스 오리지널" to SEED_NORMAL_EMAIL,
            "건희 소스 2025 버전" to "reviewer@example.test"
        )
        val favorites = favoriteSeeds.map { (recipeTitle, memberEmail) ->
            RecipeFavorite(
                recipe = recipes.getValue(recipeTitle).apply { recordFavorite() },
                member = users.getValue(memberEmail)
            )
        }
        recipeFavoriteRepository.saveAll(favorites)
        sauceRecipeRepository.saveAll(
            favorites.map { it.recipe }
        )
    }

    private data class ReviewSeed(
        val authorEmail: String,
        val recipeTitle: String,
        val rating: Int,
        val text: String,
        val tagNames: List<String>
    )

    private data class IngredientSeed(
        val name: String,
        val category: String
    )

    private data class RecipeSeed(
        val title: String,
        val description: String,
        val spiceLevel: Int,
        val richnessLevel: Int,
        val tagNames: List<String>,
        val ingredients: List<IngredientAmountSeed>,
        val authorEmail: String? = null,
        val visibility: RecipeVisibility = RecipeVisibility.VISIBLE
    )

    private data class IngredientAmountSeed(
        val name: String,
        val amount: String
    )

    private data class MemberSeed(
        val email: String,
        val nickname: String,
        val role: String = "ROLE_USER"
    )

    private data class PolicyVersionSeed(
        val policyType: PolicyType,
        val version: String,
        val title: String,
        val url: String
    )

    companion object {
        private const val SEED_NORMAL_EMAIL = "normal.user@example.test"
        private val POLICY_ACTIVE_FROM: Instant = Instant.parse("2026-05-01T00:00:00Z")

        private val POLICY_VERSION_SEEDS = listOf(
            PolicyVersionSeed(
                PolicyType.TERMS_OF_SERVICE,
                "2026-05-01",
                "서비스 이용약관",
                "nugusauce://legal/terms"
            ),
            PolicyVersionSeed(
                PolicyType.PRIVACY_POLICY,
                "2026-05-01",
                "개인정보 처리방침",
                "nugusauce://legal/privacy"
            ),
            PolicyVersionSeed(
                PolicyType.CONTENT_POLICY,
                "2026-05-01",
                "콘텐츠/사진 권리 정책",
                "nugusauce://legal/content-policy"
            )
        )

        private val MEMBER_SEEDS = listOf(
            MemberSeed(SEED_NORMAL_EMAIL, "소스장인"),
            MemberSeed("reviewer@example.test", "마라초보"),
            MemberSeed("reported.user@example.test", "신고테스터"),
            MemberSeed("admin@example.test", "운영자", "ROLE_ADMIN")
        )

        private val INGREDIENT_SEEDS = listOf(
            IngredientSeed("참기름", "oil"),
            IngredientSeed("땅콩소스", "sauce_paste"),
            IngredientSeed("다진 마늘", "fresh_aromatic"),
            IngredientSeed("고수", "fresh_aromatic"),
            IngredientSeed("다진 고추", "fresh_aromatic"),
            IngredientSeed("해선장", "sauce_paste"),
            IngredientSeed("간장", "sauce_paste"),
            IngredientSeed("식초", "vinegar_citrus"),
            IngredientSeed("설탕", "sweet_dairy"),
            IngredientSeed("파", "fresh_aromatic"),
            IngredientSeed("깨", "topping_seed"),
            IngredientSeed("고추기름", "oil"),
            IngredientSeed("스위트 칠리소스", "sauce_paste"),
            IngredientSeed("땅콩가루", "topping_seed"),
            IngredientSeed("고춧가루", "dry_seasoning"),
            IngredientSeed("볶음 소고기장", "sauce_paste"),
            IngredientSeed("마라소스", "sauce_paste"),
            IngredientSeed("참깨소스", "sauce_paste"),
            IngredientSeed("굴소스", "sauce_paste"),
            IngredientSeed("중국식초", "vinegar_citrus"),
            IngredientSeed("흑식초", "vinegar_citrus"),
            IngredientSeed("와사비", "fresh_aromatic"),
            IngredientSeed("레몬즙", "vinegar_citrus"),
            IngredientSeed("소금", "dry_seasoning"),
            IngredientSeed("맛소금", "dry_seasoning"),
            IngredientSeed("연유", "sweet_dairy"),
            IngredientSeed("들깨가루", "topping_seed"),
            IngredientSeed("양파", "fresh_aromatic"),
            IngredientSeed("태국 고추", "fresh_aromatic"),
            IngredientSeed("다진 고기", "protein"),
            IngredientSeed("마라시즈닝", "dry_seasoning"),
            IngredientSeed("청유 훠궈 소스", "sauce_paste"),
            IngredientSeed("버섯소스", "sauce_paste"),
            IngredientSeed("오향 우육", "protein"),
            IngredientSeed("매운 소고기 소스", "sauce_paste"),
            IngredientSeed("쪽파", "fresh_aromatic"),
            IngredientSeed("대파", "fresh_aromatic"),
            IngredientSeed("참깨가루", "topping_seed")
        )

        private val TAG_NAMES = listOf(
            "고소함",
            "매콤함",
            "달달함",
            "상큼함",
            "초보추천",
            "마라강함",
            "감칠맛",
            "담백함",
            "마늘향",
            "해산물추천",
            "채식추천",
            "유명조합",
            "한국식",
            "셀럽추천"
        )

        private val RECIPE_SEEDS = listOf(
            RecipeSeed(
                title = "건희 소스 오리지널",
                description = "원어스 건희가 팬 소통 채널과 SNS를 통해 알린 대표 하이디라오 소스",
                spiceLevel = 3,
                richnessLevel = 4,
                tagNames = listOf("고소함", "매콤함", "달달함", "유명조합", "셀럽추천"),
                ingredients = listOf(
                    IngredientAmountSeed("땅콩소스", "1.0"),
                    IngredientAmountSeed("스위트 칠리소스", "2.5"),
                    IngredientAmountSeed("다진 마늘", "0.5"),
                    IngredientAmountSeed("파", "0.5"),
                    IngredientAmountSeed("깨", "0.3"),
                    IngredientAmountSeed("땅콩가루", "0.3"),
                    IngredientAmountSeed("고춧가루", "0.5"),
                    IngredientAmountSeed("고추기름", "0.3"),
                    IngredientAmountSeed("설탕", "0.3"),
                    IngredientAmountSeed("볶음 소고기장", "0.5")
                )
            ),
            RecipeSeed(
                title = "건희 소스 2025 버전",
                description = "원어스 건희의 2025년식 하이디라오 소스 조합",
                spiceLevel = 3,
                richnessLevel = 5,
                tagNames = listOf("고소함", "매콤함", "감칠맛", "유명조합", "셀럽추천"),
                ingredients = listOf(
                    IngredientAmountSeed("땅콩소스", "1.0"),
                    IngredientAmountSeed("스위트 칠리소스", "1.0"),
                    IngredientAmountSeed("파", "1.0"),
                    IngredientAmountSeed("다진 마늘", "1.0"),
                    IngredientAmountSeed("고추기름", "0.3"),
                    IngredientAmountSeed("매운 소고기 소스", "0.3"),
                    IngredientAmountSeed("굴소스", "0.3"),
                    IngredientAmountSeed("태국 고추", "0.3"),
                    IngredientAmountSeed("땅콩가루", "0.3"),
                    IngredientAmountSeed("참깨가루", "0.3")
                )
            ),
            RecipeSeed(
                title = "마크 소스",
                description = "마크가 SNS로 공개한 땅콩, 간장, 굴소스 기반 하이디라오 소스",
                spiceLevel = 4,
                richnessLevel = 4,
                tagNames = listOf("고소함", "매콤함", "감칠맛", "셀럽추천"),
                ingredients = listOf(
                    IngredientAmountSeed("땅콩소스", "2.0"),
                    IngredientAmountSeed("다진 마늘", "1.5"),
                    IngredientAmountSeed("양파", "1.5"),
                    IngredientAmountSeed("굴소스", "1.0"),
                    IngredientAmountSeed("태국 고추", "1.0"),
                    IngredientAmountSeed("간장", "2.0"),
                    IngredientAmountSeed("다진 고기", "0.5"),
                    IngredientAmountSeed("파", "0.5"),
                    IngredientAmountSeed("땅콩가루", "0.3"),
                    IngredientAmountSeed("고춧가루", "0.3")
                )
            ),
            RecipeSeed(
                title = "필릭스 소스",
                description = "필릭스가 SNS로 공개한 마라시즈닝과 청유 훠궈 소스를 섞은 조합",
                spiceLevel = 5,
                richnessLevel = 4,
                tagNames = listOf("고소함", "매콤함", "마라강함", "셀럽추천"),
                ingredients = listOf(
                    IngredientAmountSeed("땅콩소스", "1.0"),
                    IngredientAmountSeed("다진 마늘", "1.0"),
                    IngredientAmountSeed("파", "0.3"),
                    IngredientAmountSeed("마라시즈닝", "1.0"),
                    IngredientAmountSeed("양파", "1.0"),
                    IngredientAmountSeed("청유 훠궈 소스", "1.0")
                )
            ),
            RecipeSeed(
                title = "숨김 처리된 샘플",
                description = "공개 목록에서 제외되어야 하는 fixture",
                spiceLevel = 2,
                richnessLevel = 2,
                tagNames = listOf("매콤함"),
                ingredients = listOf(IngredientAmountSeed("다진 고추", "1.0")),
                visibility = RecipeVisibility.HIDDEN
            ),
            RecipeSeed(
                title = "아이엔 소스",
                description = "아이엔이 SNS로 공개한 버섯소스와 오향 우육 중심의 진한 조합",
                spiceLevel = 4,
                richnessLevel = 5,
                tagNames = listOf("고소함", "매콤함", "감칠맛", "셀럽추천"),
                ingredients = listOf(
                    IngredientAmountSeed("땅콩소스", "1.0"),
                    IngredientAmountSeed("버섯소스", "1.0"),
                    IngredientAmountSeed("다진 마늘", "1.5"),
                    IngredientAmountSeed("파", "0.3"),
                    IngredientAmountSeed("오향 우육", "1.0"),
                    IngredientAmountSeed("매운 소고기 소스", "1.0")
                )
            ),
            RecipeSeed(
                title = "우기 소스",
                description = "우기가 SNS로 공개한 고수, 마늘, 식초를 강하게 쓰는 산뜻한 조합",
                spiceLevel = 2,
                richnessLevel = 3,
                tagNames = listOf("고소함", "상큼함", "마늘향", "셀럽추천"),
                ingredients = listOf(
                    IngredientAmountSeed("땅콩소스", "1.5"),
                    IngredientAmountSeed("파", "1.0"),
                    IngredientAmountSeed("고수", "1.0"),
                    IngredientAmountSeed("다진 마늘", "2.0"),
                    IngredientAmountSeed("식초", "3.0"),
                    IngredientAmountSeed("땅콩가루", "1.0")
                )
            ),
            RecipeSeed(
                title = "성찬 소스",
                description = "성찬이 SNS로 공개한 참깨소스, 칠리, 다진 고기를 넣은 고소한 조합",
                spiceLevel = 3,
                richnessLevel = 5,
                tagNames = listOf("고소함", "매콤함", "감칠맛", "셀럽추천"),
                ingredients = listOf(
                    IngredientAmountSeed("참깨소스", "2.0"),
                    IngredientAmountSeed("스위트 칠리소스", "1.0"),
                    IngredientAmountSeed("다진 고기", "2.0"),
                    IngredientAmountSeed("다진 마늘", "1.0"),
                    IngredientAmountSeed("쪽파", "2.0"),
                    IngredientAmountSeed("땅콩가루", "1.0"),
                    IngredientAmountSeed("대파", "0.5")
                )
            ),
            RecipeSeed(
                title = "소희 소스",
                description = "소희가 SNS로 공개한 참기름, 마늘, 굴소스 중심의 담백한 조합",
                spiceLevel = 2,
                richnessLevel = 3,
                tagNames = listOf("감칠맛", "담백함", "마늘향", "셀럽추천"),
                ingredients = listOf(
                    IngredientAmountSeed("참기름", "3.0"),
                    IngredientAmountSeed("다진 마늘", "1.0"),
                    IngredientAmountSeed("파", "1.0"),
                    IngredientAmountSeed("볶음 소고기장", "0.3"),
                    IngredientAmountSeed("스위트 칠리소스", "0.3"),
                    IngredientAmountSeed("굴소스", "1.0")
                )
            ),
            RecipeSeed(
                title = "지수 특제 고수 간장 소스",
                description = "블랙핑크 지수가 에스콰이어 일일 에디터 글에서 직접 소개한 고수 듬뿍 간장 소스",
                spiceLevel = 1,
                richnessLevel = 1,
                tagNames = listOf("상큼함", "담백함", "해산물추천", "셀럽추천"),
                ingredients = listOf(
                    IngredientAmountSeed("고수", "3.0"),
                    IngredientAmountSeed("파", "1.0"),
                    IngredientAmountSeed("와사비", "0.3"),
                    IngredientAmountSeed("다진 마늘", "0.5"),
                    IngredientAmountSeed("다진 고추", "0.5"),
                    IngredientAmountSeed("간장", "3.0"),
                    IngredientAmountSeed("참기름", "1.0"),
                    IngredientAmountSeed("설탕", "0.3"),
                    IngredientAmountSeed("중국식초", "1.0")
                )
            ),
            RecipeSeed(
                title = "마늘 듬뿍 고소 소스",
                description = "마늘 향이 강한 커스텀 조합",
                spiceLevel = 0,
                richnessLevel = 0,
                tagNames = emptyList(),
                ingredients = listOf(
                    IngredientAmountSeed("다진 마늘", "1.5"),
                    IngredientAmountSeed("참기름", "1.0"),
                    IngredientAmountSeed("땅콩소스", "0.5")
                ),
                authorEmail = SEED_NORMAL_EMAIL
            ),
            RecipeSeed(
                title = "고수 상큼 소스",
                description = "고수와 식초 중심의 산뜻한 조합",
                spiceLevel = 0,
                richnessLevel = 0,
                tagNames = emptyList(),
                ingredients = listOf(
                    IngredientAmountSeed("고수", "1.0"),
                    IngredientAmountSeed("식초", "1.0"),
                    IngredientAmountSeed("간장", "0.5")
                ),
                authorEmail = "reviewer@example.test"
            )
        )
    }
}
