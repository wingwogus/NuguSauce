package com.nugusauce.config

import jakarta.servlet.FilterChain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import org.slf4j.MDC
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.authority.SimpleGrantedAuthority
import org.springframework.security.core.context.SecurityContextHolder

class MDCLoggingFilterTest {

    private val filter = MDCLoggingFilter()

    @AfterEach
    fun tearDown() {
        SecurityContextHolder.clearContext()
        MDC.clear()
    }

    @Test
    fun `adds request ids client ip and authenticated user id to MDC`() {
        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken(
            "42",
            null,
            listOf(SimpleGrantedAuthority("ROLE_USER"))
        )

        val request = MockHttpServletRequest("GET", "/api/v1/test/me").apply {
            remoteAddr = "10.0.0.10"
            addHeader("X-Forwarded-For", "203.0.113.10, 10.0.0.11")
        }
        val response = MockHttpServletResponse()

        val chain = FilterChain { _, _ ->
            assertNotNull(MDC.get("traceId"))
            assertNotNull(MDC.get("eventId"))
            assertEquals("203.0.113.10", MDC.get("clientIp"))
            assertEquals("42", MDC.get("userId"))
        }

        filter.doFilter(request, response, chain)

        assertNull(MDC.get("traceId"))
        assertNull(MDC.get("eventId"))
        assertNull(MDC.get("clientIp"))
        assertNull(MDC.get("userId"))
    }

    @Test
    fun `uses GUEST user id when request is unauthenticated`() {
        val request = MockHttpServletRequest("GET", "/api/v1/recipes").apply {
            remoteAddr = "10.0.0.10"
        }
        val response = MockHttpServletResponse()

        val chain = FilterChain { _, _ ->
            assertNotNull(MDC.get("traceId"))
            assertNotNull(MDC.get("eventId"))
            assertEquals("10.0.0.10", MDC.get("clientIp"))
            assertEquals("GUEST", MDC.get("userId"))
        }

        filter.doFilter(request, response, chain)

        assertNull(MDC.get("userId"))
    }
}
