package com.nugusauce.api.analytics

import com.nugusauce.api.exception.GlobalExceptionHandler
import com.nugusauce.application.security.TokenProvider
import io.micrometer.core.instrument.simple.SimpleMeterRegistry
import org.hamcrest.Matchers.equalTo
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import org.springframework.boot.test.mock.mockito.MockBean

@WebMvcTest(AnalyticsController::class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler::class, AnalyticsControllerTest.Config::class)
class AnalyticsControllerTest(
    @Autowired private val mockMvc: MockMvc,
    @Autowired private val meterRegistry: SimpleMeterRegistry,
) {
    @MockBean
    private lateinit var tokenProvider: TokenProvider

    @Test
    fun `accepts allowlisted funnel event and increments metric`() {
        mockMvc.perform(
            post("/api/v1/analytics/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "eventName": "search_submitted",
                      "sessionId": "1f74e568-4ca7-4c4d-87d4-58abf5ea4160",
                      "screen": "search",
                      "hasQuery": true,
                      "tagCount": 2,
                      "ingredientCount": 1,
                      "resultCount": 8,
                      "appVersion": "1.0.2"
                    }
                    """.trimIndent()
                )
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.success").value(true))

        val count = meterRegistry.get("nugusauce.analytics.events")
            .tag("event_name", "search_submitted")
            .counter()
            .count()
        assertEquals(1.0, count)
    }

    @Test
    fun `rejects event names outside the allowlist`() {
        mockMvc.perform(
            post("/api/v1/analytics/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "eventName": "raw_user_message",
                      "sessionId": "1f74e568-4ca7-4c4d-87d4-58abf5ea4160",
                      "screen": "search"
                    }
                    """.trimIndent()
                )
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.error.code", equalTo("COMMON_001")))
    }

    @Test
    fun `rejects unknown fields to prevent accidental content collection`() {
        mockMvc.perform(
            post("/api/v1/analytics/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "eventName": "screen_view",
                      "sessionId": "1f74e568-4ca7-4c4d-87d4-58abf5ea4160",
                      "screen": "home",
                      "searchText": "민감한 원문"
                    }
                    """.trimIndent()
                )
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.error.code", equalTo("COMMON_002")))
    }

    @org.springframework.boot.test.context.TestConfiguration
    class Config {
        @org.springframework.context.annotation.Bean
        fun meterRegistry() = SimpleMeterRegistry()
    }
}
