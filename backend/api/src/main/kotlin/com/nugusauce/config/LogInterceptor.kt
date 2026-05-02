package com.nugusauce.config

import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import org.springframework.web.servlet.HandlerInterceptor

@Component
class LogInterceptor : HandlerInterceptor {

    private val logger = LoggerFactory.getLogger(javaClass)

    override fun preHandle(
        request: HttpServletRequest,
        response: HttpServletResponse,
        handler: Any
    ): Boolean {
        request.setAttribute(START_TIME_ATTRIBUTE, System.currentTimeMillis())
        logger.info("[REQ START] {} {}, client: {}", request.method, request.requestURI, resolveClientIp(request))
        return true
    }

    override fun afterCompletion(
        request: HttpServletRequest,
        response: HttpServletResponse,
        handler: Any,
        ex: Exception?
    ) {
        val startTime = request.getAttribute(START_TIME_ATTRIBUTE) as? Long ?: System.currentTimeMillis()
        val duration = System.currentTimeMillis() - startTime
        val status = response.status
        val clientIp = resolveClientIp(request)

        if (status >= 400) {
            logger.warn(
                "[REQ END] {} {}, status: {}, duration: {}ms, client: {}",
                request.method,
                request.requestURI,
                status,
                duration,
                clientIp
            )
        } else {
            logger.info(
                "[REQ END] {} {}, status: {}, duration: {}ms, client: {}",
                request.method,
                request.requestURI,
                status,
                duration,
                clientIp
            )
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
        private const val START_TIME_ATTRIBUTE = "nugusauce.requestStartTime"

        private val CLIENT_IP_HEADERS = listOf(
            "X-Forwarded-For",
            "Proxy-Client-IP",
            "WL-Proxy-Client-IP",
            "HTTP_CLIENT_IP",
            "HTTP_X_FORWARDED_FOR",
        )
    }
}
