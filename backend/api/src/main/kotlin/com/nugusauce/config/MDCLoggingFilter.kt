package com.nugusauce.config

import com.nugusauce.application.common.LoggingUtil
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.MDC
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import java.util.*

@Component
class MDCLoggingFilter : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        try {
            MDC.put("traceId", UUID.randomUUID().toString())
            MDC.put("eventId", LoggingUtil.generateEventId())
            MDC.put("clientIp", resolveClientIp(request))
            MDC.put("userId", resolveUserId())

            filterChain.doFilter(request, response)
        } finally {
            MDC.clear()
        }
    }

    private fun resolveUserId(): String {
        val authentication = SecurityContextHolder.getContext().authentication ?: return GUEST_USER_ID
        if (!authentication.isAuthenticated) return GUEST_USER_ID

        return when (val principal = authentication.principal) {
            is String -> principal.takeUnless { it.isBlank() || it == ANONYMOUS_PRINCIPAL } ?: GUEST_USER_ID
            else -> GUEST_USER_ID
        }
    }

    private fun resolveClientIp(request: HttpServletRequest): String {
        val headerValue = CLIENT_IP_HEADERS
            .asSequence()
            .mapNotNull { request.getHeader(it) }
            .firstOrNull { it.isNotBlank() && !it.equals("unknown", ignoreCase = true) }

        return (headerValue ?: request.remoteAddr)
            .substringBefore(",")
            .trim()
    }

    companion object {
        private const val GUEST_USER_ID = "GUEST"
        private const val ANONYMOUS_PRINCIPAL = "anonymousUser"

        private val CLIENT_IP_HEADERS = listOf(
            "X-Forwarded-For",
            "Proxy-Client-IP",
            "WL-Proxy-Client-IP",
            "HTTP_CLIENT_IP",
            "HTTP_X_FORWARDED_FOR",
        )
    }
}
