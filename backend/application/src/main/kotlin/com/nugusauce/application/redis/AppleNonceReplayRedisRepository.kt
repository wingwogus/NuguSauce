package com.nugusauce.application.redis

import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.stereotype.Repository
import java.time.Duration
import java.util.concurrent.TimeUnit

@Repository
class AppleNonceReplayRedisRepository(
    private val redis: StringRedisTemplate
) : AppleNonceReplayRepository {

    override fun reserve(nonceHash: String, ttl: Duration): Boolean {
        if (ttl.isZero || ttl.isNegative) {
            return false
        }

        return redis.opsForValue().setIfAbsent(
            PREFIX + nonceHash,
            "1",
            ttl.toMillis().coerceAtLeast(1L),
            TimeUnit.MILLISECONDS
        ) == true
    }

    companion object {
        private const val PREFIX = "auth:apple:nonce:"
    }
}
