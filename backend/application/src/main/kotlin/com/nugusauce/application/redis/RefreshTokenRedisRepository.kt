package com.nugusauce.application.redis

import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.stereotype.Repository
import java.util.concurrent.TimeUnit

@Repository
class RefreshTokenRedisRepository(
    private val redis: StringRedisTemplate
) : RefreshTokenRepository {

    companion object {
        private const val PREFIX = "refresh:"
    }

    override fun save(
        userId: Long,
        refreshToken: String,
        expiresInSeconds: Long
    ) {
        redis.opsForValue().set(
            PREFIX + userId,
            refreshToken,
            expiresInSeconds,
            TimeUnit.SECONDS
        )
    }

    override fun get(userId: Long): String? {
        return redis.opsForValue().get(PREFIX + userId)
    }

    override fun delete(userId: Long) {
        redis.delete(PREFIX + userId)
    }
}