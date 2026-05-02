package com.nugusauce.config

import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.springframework.boot.test.system.CapturedOutput
import org.springframework.boot.test.system.OutputCaptureExtension
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.web.method.HandlerMethod

@ExtendWith(OutputCaptureExtension::class)
class LogInterceptorTest {

    private val interceptor = LogInterceptor()

    @Test
    fun `logs request start and successful completion with status duration and client ip`(
        output: CapturedOutput
    ) {
        val request = MockHttpServletRequest("GET", "/api/v1/recipes").apply {
            remoteAddr = "10.0.0.10"
            addHeader("X-Forwarded-For", "203.0.113.10, 10.0.0.11")
        }
        val response = MockHttpServletResponse().apply {
            status = 200
        }

        interceptor.preHandle(request, response, handler())
        interceptor.afterCompletion(request, response, handler(), null)

        assertTrue(output.out.contains("[REQ START] GET /api/v1/recipes, client: 203.0.113.10"))
        assertTrue(output.out.contains("[REQ END] GET /api/v1/recipes, status: 200, duration: "))
        assertTrue(output.out.contains("ms, client: 203.0.113.10"))
    }

    @Test
    fun `logs failed completion with warn-shaped request end line`(
        output: CapturedOutput
    ) {
        val request = MockHttpServletRequest("POST", "/api/v1/recipes").apply {
            remoteAddr = "10.0.0.10"
        }
        val response = MockHttpServletResponse().apply {
            status = 401
        }

        interceptor.preHandle(request, response, handler())
        interceptor.afterCompletion(request, response, handler(), null)

        assertTrue(output.out.contains("[REQ END] POST /api/v1/recipes, status: 401, duration: "))
        assertTrue(output.out.contains("ms, client: 10.0.0.10"))
    }

    private fun handler(): HandlerMethod {
        return HandlerMethod(TestHandler(), TestHandler::class.java.getDeclaredMethod("handle"))
    }

    private class TestHandler {
        fun handle() = Unit
    }
}
