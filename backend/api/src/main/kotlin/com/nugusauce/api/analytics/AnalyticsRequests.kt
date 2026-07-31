package com.nugusauce.api.analytics

import com.fasterxml.jackson.annotation.JsonAnySetter
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.Positive
import jakarta.validation.constraints.Size

object AnalyticsRequests {
    data class EventRequest(
        @field:Pattern(
            regexp = "screen_view|search_submitted|recipe_detail_view|favorite_success|recipe_create_start|recipe_create_success|login_start|login_success|login_failure",
            message = "Unsupported analytics event"
        )
        val eventName: String,
        @field:NotBlank
        @field:Pattern(
            regexp = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}",
            message = "Invalid analytics session"
        )
        val sessionId: String,
        @field:Pattern(regexp = "home|favorites|create|search|profile|recipe_detail|login")
        val screen: String,
        @field:Pattern(regexp = "kakao|apple")
        val provider: String? = null,
        @field:Positive
        val recipeId: Long? = null,
        val favoriteState: Boolean? = null,
        val hasQuery: Boolean? = null,
        @field:Min(0)
        @field:Max(20)
        val tagCount: Int? = null,
        @field:Min(0)
        @field:Max(100)
        val ingredientCount: Int? = null,
        @field:Min(0)
        @field:Max(1000)
        val resultCount: Int? = null,
        @field:Pattern(regexp = "[0-9]+(?:\\.[0-9]+){0,2}(?:[-+][A-Za-z0-9.-]+)?")
        val appVersion: String? = null,
    ) {
        @JsonAnySetter
        fun rejectUnknownField(name: String, @Suppress("UNUSED_PARAMETER") value: Any?) {
            throw IllegalArgumentException("Unknown analytics field: $name")
        }
    }
}
