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
    fun `logs one structured completion event with route status and duration`(
        output: CapturedOutput
    ) {
        val request = MockHttpServletRequest("GET", "/api/v1/recipes/42").apply {
            setAttribute(
                org.springframework.web.servlet.HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE,
                "/api/v1/recipes/{recipeId}"
            )
        }
        val response = MockHttpServletResponse().apply {
            status = 200
        }

        interceptor.preHandle(request, response, handler())
        interceptor.afterCompletion(request, response, handler(), null)

        assertTrue(output.out.contains("http.request.completed"))
        assertTrue(output.out.contains("method=\"GET\""))
        assertTrue(output.out.contains("route=\"/api/v1/recipes/{recipeId}\""))
        assertTrue(output.out.contains("status=\"200\""))
        assertTrue(output.out.contains("duration_ms=\""))
        assertTrue(!output.out.contains("REQ START"))
        assertTrue(!output.out.contains("client"))
    }

    @Test
    fun `logs failed completion with warn-shaped request end line`(
        output: CapturedOutput
    ) {
        val request = MockHttpServletRequest("POST", "/api/v1/recipes")
        val response = MockHttpServletResponse().apply {
            status = 401
        }

        interceptor.preHandle(request, response, handler())
        interceptor.afterCompletion(request, response, handler(), null)

        assertTrue(output.out.contains("http.request.completed"))
        assertTrue(output.out.contains("method=\"POST\""))
        assertTrue(output.out.contains("route=\"/api/v1/recipes\""))
        assertTrue(output.out.contains("status=\"401\""))
    }

    private fun handler(): HandlerMethod {
        return HandlerMethod(TestHandler(), TestHandler::class.java.getDeclaredMethod("handle"))
    }

    private class TestHandler {
        fun handle() = Unit
    }
}
