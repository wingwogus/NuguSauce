package com.nugusauce.config


import com.nugusauce.application.common.LoggingUtil
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.MDC
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import java.util.*

@Component
class LoggingFilter : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        chain: FilterChain
    ) {
        try {
            MDC.put("traceId", UUID.randomUUID().toString())
            MDC.put("eventId", LoggingUtil.generateEventId())
            MDC.put("clientIp", request.remoteAddr)

            logger.info("Incoming request: ${request.method} ${request.requestURI}")

            chain.doFilter(request, response)
        } finally {
            MDC.clear()
        }
    }
}
