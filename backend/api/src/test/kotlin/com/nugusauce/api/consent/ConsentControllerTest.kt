package com.nugusauce.api.consent

import com.nugusauce.api.exception.GlobalExceptionHandler
import com.nugusauce.application.consent.ConsentCommand
import com.nugusauce.application.consent.ConsentResult
import com.nugusauce.application.consent.ConsentService
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
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
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.Instant

@WebMvcTest(ConsentController::class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler::class)
class ConsentControllerTest(
    @Autowired private val mockMvc: MockMvc
) {
    @MockBean
    private lateinit var consentService: ConsentService

    @MockBean
    private lateinit var tokenProvider: TokenProvider

    @AfterEach
    fun tearDown() {
        SecurityContextHolder.clearContext()
    }

    @Test
    fun `status returns current required consent state`() {
        `when`(consentService.status(1L)).thenReturn(consentStatus(accepted = false))
        authenticate()

        mockMvc.perform(get("/api/v1/consents/status"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.data.requiredConsentsAccepted", equalTo(false)))
            .andExpect(jsonPath("$.data.missingPolicies[0].policyType", equalTo("terms_of_service")))
            .andExpect(jsonPath("$.data.missingPolicies[0].version", equalTo("2026-05-01")))
    }

    @Test
    fun `accept stores policy versions and returns updated status`() {
        `when`(
            consentService.accept(
                ConsentCommand.Accept(
                    memberId = 1L,
                    acceptedPolicies = listOf(
                        ConsentCommand.PolicyAcceptance(
                            policyType = "terms_of_service",
                            version = "2026-05-01"
                        )
                    )
                )
            )
        ).thenReturn(consentStatus(accepted = true))
        authenticate()

        mockMvc.perform(
            post("/api/v1/consents/accept")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "acceptedPolicies": [
                        { "policyType": "terms_of_service", "version": "2026-05-01" }
                      ]
                    }
                    """.trimIndent()
                )
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.data.requiredConsentsAccepted", equalTo(true)))
            .andExpect(jsonPath("$.data.missingPolicies.length()", equalTo(0)))
    }

    @Test
    fun `missing required consent maps to stable error`() {
        doThrow(
            BusinessException(
                ErrorCode.CONSENT_REQUIRED,
                detail = mapOf("missingPolicies" to listOf(mapOf("policyType" to "privacy_policy")))
            )
        ).`when`(consentService).status(1L)
        authenticate()

        mockMvc.perform(get("/api/v1/consents/status"))
            .andExpect(status().`is`(428))
            .andExpect(jsonPath("$.error.code", equalTo("CONSENT_001")))
            .andExpect(jsonPath("$.error.detail.missingPolicies[0].policyType", equalTo("privacy_policy")))
    }

    private fun authenticate() {
        SecurityContextHolder.getContext().authentication = TestingAuthenticationToken("1", null, "ROLE_USER")
    }

    private fun consentStatus(accepted: Boolean): ConsentResult.Status {
        val policy = ConsentResult.PolicyStatus(
            policyType = "terms_of_service",
            version = "2026-05-01",
            title = "서비스 이용약관",
            url = "nugusauce://legal/terms",
            required = true,
            accepted = accepted,
            activeFrom = Instant.parse("2026-05-01T00:00:00Z")
        )
        return ConsentResult.Status(
            policies = listOf(policy),
            missingPolicies = if (accepted) emptyList() else listOf(policy),
            requiredConsentsAccepted = accepted
        )
    }
}
