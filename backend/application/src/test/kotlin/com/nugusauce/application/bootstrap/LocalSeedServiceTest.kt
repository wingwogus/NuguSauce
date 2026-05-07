package com.nugusauce.application.bootstrap

import com.nugusauce.domain.consent.PolicyType
import com.nugusauce.domain.consent.PolicyVersion
import com.nugusauce.domain.consent.PolicyVersionRepository
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.recipe.favorite.RecipeFavoriteRepository
import com.nugusauce.domain.recipe.ingredient.IngredientRepository
import com.nugusauce.domain.recipe.report.RecipeReportRepository
import com.nugusauce.domain.recipe.review.RecipeReviewRepository
import com.nugusauce.domain.recipe.sauce.SauceRecipeRepository
import com.nugusauce.domain.recipe.tag.RecipeTagRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.ArgumentCaptor
import org.mockito.ArgumentMatchers.anyString
import org.mockito.Mock
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import org.springframework.boot.ApplicationArguments
import org.springframework.security.crypto.password.PasswordEncoder

@ExtendWith(MockitoExtension::class)
class LocalSeedServiceTest {
    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var policyVersionRepository: PolicyVersionRepository

    @Mock
    private lateinit var ingredientRepository: IngredientRepository

    @Mock
    private lateinit var recipeTagRepository: RecipeTagRepository

    @Mock
    private lateinit var sauceRecipeRepository: SauceRecipeRepository

    @Mock
    private lateinit var recipeReviewRepository: RecipeReviewRepository

    @Mock
    private lateinit var recipeReportRepository: RecipeReportRepository

    @Mock
    private lateinit var recipeFavoriteRepository: RecipeFavoriteRepository

    @Mock
    private lateinit var passwordEncoder: PasswordEncoder

    private lateinit var service: LocalSeedService

    @BeforeEach
    fun setUp() {
        service = LocalSeedService(
            memberRepository,
            policyVersionRepository,
            ingredientRepository,
            recipeTagRepository,
            sauceRecipeRepository,
            recipeReviewRepository,
            recipeReportRepository,
            recipeFavoriteRepository,
            passwordEncoder
        )
    }

    @Test
    fun `run seeds required policies even when product fixtures already exist`() {
        val existingSeedMember = Member(1L, SEED_NORMAL_EMAIL, "hash", "ROLE_USER").apply {
            nickname = "소스장인"
        }
        `when`(policyVersionRepository.findAll()).thenReturn(emptyList())
        `when`(memberRepository.findByEmail(anyString())).thenAnswer { invocation ->
            val email = invocation.getArgument<String>(0)
            if (email == SEED_NORMAL_EMAIL) existingSeedMember else null
        }

        service.run(mock(ApplicationArguments::class.java))

        @Suppress("UNCHECKED_CAST")
        val captor = ArgumentCaptor.forClass(Iterable::class.java) as ArgumentCaptor<Iterable<PolicyVersion>>
        verify(policyVersionRepository).saveAll(captor.capture())
        val policies = captor.value.toList()
        assertEquals(3, policies.size)
        assertEquals(PolicyType.values().toSet(), policies.map { it.policyType }.toSet())
        assertTrue(policies.all { it.version == "2026-05-01" })
        assertTrue(policies.all { it.url.startsWith("nugusauce://legal/") })
    }

    private companion object {
        const val SEED_NORMAL_EMAIL = "normal.user@example.test"
    }
}
