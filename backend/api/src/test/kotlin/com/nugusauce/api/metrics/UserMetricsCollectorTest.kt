package com.nugusauce.api.metrics

import com.nugusauce.application.metrics.UserMetricsQueryService
import com.nugusauce.application.metrics.UserMetricsSnapshot
import io.micrometer.core.instrument.simple.SimpleMeterRegistry
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.mockito.Mockito.*
import java.time.Clock
import java.time.Instant

class UserMetricsCollectorTest {
    private val queryService = mock(UserMetricsQueryService::class.java)
    private val registry = SimpleMeterRegistry()
    private val now = Instant.parse("2026-11-07T00:00:00Z")
    private val clock = mock(Clock::class.java)
    private val collector = UserMetricsCollector(queryService, registry, clock)

    @Test
    fun `all gauges start unknown and scrape does not collect`() {
        repeat(2) { assertTrue(values().all(Double::isNaN)) }
        verifyNoInteractions(queryService)
    }

    @Test
    fun `successful empty collection publishes zero and a completion timestamp`() {
        `when`(queryService.collect()).thenReturn(snapshot(0, 0, 0, 0))
        `when`(clock.instant()).thenReturn(now)
        collector.refresh()

        assertEquals(listOf(0.0, 0.0, now.epochSecond.toDouble(), 0.0, 0.0), values())
        repeat(3) { values() }
        verify(queryService, times(1)).collect()
        assertEquals(setOf("APPLE", "KAKAO"), registry.find("nugusauce_users_registered_by_provider")
            .gauges().map { it.id.getTag("provider") }.toSet())
        assertTrue(registry.meters.all { meter -> meter.id.tags.all { it.key == "provider" } })
    }

    @Test
    fun `failed initial collection stays unknown then recovers`() {
        `when`(queryService.collect()).thenThrow(IllegalStateException("unavailable"))
            .thenReturn(snapshot(7, 2, 4, 3))
        `when`(clock.instant()).thenReturn(now)
        collector.refresh()
        assertTrue(values().all(Double::isNaN))
        verifyNoInteractions(clock)
        collector.refresh()
        assertEquals(listOf(7.0, 2.0, now.epochSecond.toDouble(), 4.0, 3.0), values())
    }

    @Test
    fun `failure retains all counts and freshness then publishes recovered collection`() {
        `when`(queryService.collect()).thenReturn(snapshot(7, 2, 4, 3))
            .thenThrow(IllegalStateException("unavailable"))
            .thenReturn(snapshot(8, 1, 5, 3))
        `when`(clock.instant()).thenReturn(now, now.plusSeconds(120))
        collector.refresh()
        val original = values()
        collector.refresh()
        assertEquals(original, values())
        collector.refresh()
        assertEquals(listOf(8.0, 1.0, now.plusSeconds(120).epochSecond.toDouble(), 5.0, 3.0), values())
    }

    private fun values() = listOf(
        registry.get("nugusauce_users_registered").gauge().value(),
        registry.get("nugusauce_users_logged_in").gauge().value(),
        registry.get("nugusauce_users_metrics_last_success_timestamp_seconds").gauge().value(),
        registry.get("nugusauce_users_registered_by_provider").tag("provider", "APPLE").gauge().value(),
        registry.get("nugusauce_users_registered_by_provider").tag("provider", "KAKAO").gauge().value()
    )

    private fun snapshot(total: Long, active: Long, apple: Long, kakao: Long) =
        UserMetricsSnapshot(total, mapOf("APPLE" to apple, "KAKAO" to kakao), active)
}
