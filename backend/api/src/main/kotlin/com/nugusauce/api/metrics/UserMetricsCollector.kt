package com.nugusauce.api.metrics

import com.nugusauce.application.metrics.UserMetricsQueryService
import com.nugusauce.application.metrics.UserMetricsSnapshot
import io.micrometer.core.instrument.Gauge
import io.micrometer.core.instrument.MeterRegistry
import mu.KotlinLogging
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import java.time.Clock
import java.time.Instant
import java.util.concurrent.atomic.AtomicReference

@Component
class UserMetricsCollector(
    private val userMetricsQueryService: UserMetricsQueryService,
    meterRegistry: MeterRegistry,
    private val clock: Clock = Clock.systemUTC()
) {

    private val logger = KotlinLogging.logger {}
    private val cachedSnapshot = AtomicReference<CachedUserMetrics?>(null)

    init {
        Gauge.builder("nugusauce_users_registered", cachedSnapshot) {
            it.get()?.registered?.toDouble() ?: Double.NaN
        }.register(meterRegistry)
        Gauge.builder("nugusauce_users_logged_in", cachedSnapshot) {
            it.get()?.loggedIn?.toDouble() ?: Double.NaN
        }.register(meterRegistry)
        Gauge.builder("nugusauce_users_metrics_last_success_timestamp_seconds", cachedSnapshot) {
            it.get()?.lastSuccessTimestampSeconds ?: Double.NaN
        }.register(meterRegistry)

        PROVIDERS.forEach { provider ->
            Gauge.builder("nugusauce_users_registered_by_provider", cachedSnapshot) {
                it.get()?.registeredByProvider?.get(provider)?.toDouble() ?: Double.NaN
            }
                .tag("provider", provider)
                .register(meterRegistry)
        }
    }

    @Scheduled(fixedDelay = REFRESH_INTERVAL_MILLIS, initialDelay = 0L)
    fun refresh() {
        try {
            val snapshot = userMetricsQueryService.collect()
            cachedSnapshot.set(CachedUserMetrics.from(snapshot, clock.instant()))
        } catch (exception: Exception) {
            logger.warn { "Failed to refresh user metrics snapshot: ${exception::class.simpleName}" }
        }
    }

    private data class CachedUserMetrics(
        val registered: Long,
        val registeredByProvider: Map<String, Long>,
        val loggedIn: Long,
        val lastSuccessTimestampSeconds: Double
    ) {
        companion object {
            fun from(snapshot: UserMetricsSnapshot, now: Instant) = CachedUserMetrics(
                registered = snapshot.registered,
                registeredByProvider = snapshot.registeredByProvider.toMap(),
                loggedIn = snapshot.loggedIn,
                lastSuccessTimestampSeconds = now.toEpochMilli() / 1000.0
            )
        }
    }

    private companion object {
        const val REFRESH_INTERVAL_MILLIS = 60_000L
        val PROVIDERS = listOf("APPLE", "KAKAO")
    }
}
