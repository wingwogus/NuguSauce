package com.nugusauce.config

import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import org.springframework.web.servlet.HandlerMapping
import org.springframework.web.servlet.HandlerInterceptor

@Component
class LogInterceptor : HandlerInterceptor {

    private val logger = LoggerFactory.getLogger(javaClass)

    override fun preHandle(
        request: HttpServletRequest,
        response: HttpServletResponse,
        handler: Any
    ): Boolean {
        request.setAttribute(START_TIME_ATTRIBUTE, System.nanoTime())
        return true
    }

    override fun afterCompletion(
        request: HttpServletRequest,
        response: HttpServletResponse,
        handler: Any,
        ex: Exception?
    ) {
        val startTime = request.getAttribute(START_TIME_ATTRIBUTE) as? Long ?: System.nanoTime()
        val duration = (System.nanoTime() - startTime) / 1_000_000
        val status = response.status
        val route = request.getAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE) as? String
            ?: request.requestURI
        val event = logger.atLevel(if (status >= 500) org.slf4j.event.Level.ERROR else org.slf4j.event.Level.INFO)
            .addKeyValue("method", request.method)
            .addKeyValue("route", route)
            .addKeyValue("status", status)
            .addKeyValue("duration_ms", duration)
        ex?.let { event.setCause(it) }
        event.log("http.request.completed")
    }

    companion object {
        private const val START_TIME_ATTRIBUTE = "nugusauce.requestStartTime"

    }
}
