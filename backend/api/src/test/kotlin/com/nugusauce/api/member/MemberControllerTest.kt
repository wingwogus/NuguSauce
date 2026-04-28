package com.nugusauce.api.member

import com.nugusauce.api.exception.GlobalExceptionHandler
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.member.MemberCommand
import com.nugusauce.application.member.MemberResult
import com.nugusauce.application.member.MemberService
import com.nugusauce.application.recipe.RecipeResult
import com.nugusauce.application.security.TokenProvider
import org.hamcrest.Matchers.equalTo
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test
import org.mockito.Mockito.doThrow
import org.mockito.Mockito.`when`
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest
import org.springframework.boot.test.mock.mockito.MockBean
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.security.authentication.TestingAuthenticationToken
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.RequestPostProcessor
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.Instant

@WebMvcTest(MemberController::class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler::class)
class MemberControllerTest(
    @Autowired private val mockMvc: MockMvc
) {
    @MockBean
    private lateinit var memberService: MemberService

    @MockBean
    private lateinit var tokenProvider: TokenProvider

    @AfterEach
    fun tearDown() {
        SecurityContextHolder.clearContext()
    }

    @Test
    fun `getMe returns authenticated member profile`() {
        `when`(memberService.getMe(1L)).thenReturn(
            MemberResult.Me(
                id = 1L,
                nickname = null,
                displayName = "사용자 1",
                profileSetupRequired = true
            )
        )

        mockMvc.perform(
            get("/api/v1/members/me")
                .with(authenticatedUser())
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.data.id", equalTo(1)))
            .andExpect(jsonPath("$.data.displayName", equalTo("사용자 1")))
            .andExpect(jsonPath("$.data.profileSetupRequired", equalTo(true)))
    }

    @Test
    fun `updateMe returns updated profile`() {
        `when`(memberService.updateMe(MemberCommand.UpdateMe(1L, "소스장인")))
            .thenReturn(
                MemberResult.Me(
                    id = 1L,
                    nickname = "소스장인",
                    displayName = "소스장인",
                    profileSetupRequired = false
                )
            )

        mockMvc.perform(
            patch("/api/v1/members/me")
                .with(authenticatedUser())
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"nickname":"소스장인"}""")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.data.nickname", equalTo("소스장인")))
            .andExpect(jsonPath("$.data.profileSetupRequired", equalTo(false)))
    }

    @Test
    fun `getMember returns public member profile`() {
        `when`(memberService.getPublicProfile(2L))
            .thenReturn(
                MemberResult.PublicProfile(
                    id = 2L,
                    nickname = "마라초보",
                    displayName = "마라초보",
                    profileSetupRequired = false,
                    recipes = listOf(recipeSummary(10L, "공개 소스")),
                    favoriteRecipes = listOf(recipeSummary(11L, "찜 소스"))
                )
            )

        mockMvc.perform(get("/api/v1/members/2"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.data.id", equalTo(2)))
            .andExpect(jsonPath("$.data.nickname", equalTo("마라초보")))
            .andExpect(jsonPath("$.data.displayName", equalTo("마라초보")))
            .andExpect(jsonPath("$.data.profileSetupRequired", equalTo(false)))
            .andExpect(jsonPath("$.data.recipes[0].id", equalTo(10)))
            .andExpect(jsonPath("$.data.favoriteRecipes[0].id", equalTo(11)))
    }

    @Test
    fun `updateMe maps duplicate nickname to stable error`() {
        doThrow(object : BusinessException(ErrorCode.DUPLICATE_NICKNAME) {})
            .`when`(memberService)
            .updateMe(MemberCommand.UpdateMe(1L, "소스장인"))

        mockMvc.perform(
            patch("/api/v1/members/me")
                .with(authenticatedUser())
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"nickname":"소스장인"}""")
        )
            .andExpect(status().isConflict)
            .andExpect(jsonPath("$.error.code", equalTo("USER_004")))
    }

    private fun authenticatedUser(): RequestPostProcessor {
        return RequestPostProcessor { request ->
            val context = SecurityContextHolder.createEmptyContext()
            context.authentication = TestingAuthenticationToken("1", null, "ROLE_USER")
            SecurityContextHolder.setContext(context)
            request
        }
    }

    private fun recipeSummary(id: Long, title: String): RecipeResult.RecipeSummary {
        return RecipeResult.RecipeSummary(
            id = id,
            title = title,
            description = "설명",
            spiceLevel = 3,
            richnessLevel = 4,
            imageUrl = null,
            authorType = "USER",
            visibility = "VISIBLE",
            ratingSummary = RecipeResult.RatingSummary(0.0, 0),
            tags = emptyList(),
            reviewTags = emptyList(),
            createdAt = Instant.parse("2026-04-25T00:00:00Z")
        )
    }
}
