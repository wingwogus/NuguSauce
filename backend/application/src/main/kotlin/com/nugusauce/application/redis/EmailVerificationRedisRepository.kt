package com.nugusauce.application.redis

import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.stereotype.Repository
import java.time.Duration

@Repository
class EmailVerificationRedisRepository(
    private val redis: StringRedisTemplate
) : EmailVerificationRepository {

    companion object {
        private const val AUTH_CODE_PREFIX = "auth-code:"
        private const val VERIFIED_PREFIX = "verified-email:"
    }

    override fun saveCode(email: String, code: String, ttl: Duration) {
        redis.opsForValue().set(AUTH_CODE_PREFIX + email, code, ttl)
        redis.delete(VERIFIED_PREFIX + email)
    }

    override fun getCode(email: String): String? {
        return redis.opsForValue().get(AUTH_CODE_PREFIX + email)
    }

    override fun markVerified(email: String, ttl: Duration) {
        redis.opsForValue().set(VERIFIED_PREFIX + email, "true", ttl)
    }

    override fun isVerified(email: String): Boolean {
        return redis.opsForValue().get(VERIFIED_PREFIX + email) == "true"
    }

    override fun deleteCode(email: String) {
        redis.delete(AUTH_CODE_PREFIX + email)
    }

    override fun deleteVerified(email: String) {
        redis.delete(VERIFIED_PREFIX + email)
    }
}
