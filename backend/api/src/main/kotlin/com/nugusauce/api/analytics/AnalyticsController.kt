package com.nugusauce.api.analytics

import com.nugusauce.api.common.ApiResponse
import io.micrometer.core.instrument.MeterRegistry
import jakarta.validation.Valid
import org.slf4j.LoggerFactory
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/analytics")
class AnalyticsController(
    private val meterRegistry: MeterRegistry,
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    @PostMapping("/events")
    fun record(@Valid @RequestBody request: AnalyticsRequests.EventRequest): ApiResponse<Unit> {
        meterRegistry.counter(
            "nugusauce.analytics.events",
            "event_name",
            request.eventName,
        ).increment()

        logger.atInfo()
            .addKeyValue("event_name", request.eventName)
            .addKeyValue("analytics_session_id", request.sessionId)
            .addKeyValue("screen", request.screen)
            .addKeyValue("provider", request.provider)
            .addKeyValue("recipe_id", request.recipeId)
            .addKeyValue("favorite_state", request.favoriteState)
            .addKeyValue("has_query", request.hasQuery)
            .addKeyValue("tag_count", request.tagCount)
            .addKeyValue("ingredient_count", request.ingredientCount)
            .addKeyValue("result_count", request.resultCount)
            .addKeyValue("app_version", request.appVersion)
            .log("analytics.event")

        return ApiResponse.empty(Unit)
    }
}
