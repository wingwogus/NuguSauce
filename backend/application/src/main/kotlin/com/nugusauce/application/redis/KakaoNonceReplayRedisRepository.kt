package com.nugusauce.application.redis

import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.stereotype.Repository
import java.security.MessageDigest
import java.time.Duration
import java.util.concurrent.TimeUnit

@Repository
class KakaoNonceReplayRedisRepository(
    private val redis: StringRedisTemplate
) : KakaoNonceReplayRepository {

    override fun reserve(nonce: String, ttl: Duration): Boolean {
        if (ttl.isZero || ttl.isNegative) {
            return false
        }

        return redis.opsForValue().setIfAbsent(
            PREFIX + sha256Hex(nonce),
            "1",
            ttl.toMillis().coerceAtLeast(1L),
            TimeUnit.MILLISECONDS
        ) == true
    }

    private fun sha256Hex(value: String): String {
        return MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }

    companion object {
        private const val PREFIX = "auth:kakao:nonce:"
    }
}
