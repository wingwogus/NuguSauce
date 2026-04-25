package com.nugusauce.application.redis

import java.time.Duration

interface EmailVerificationRepository {
    fun saveCode(email: String, code: String, ttl: Duration)

    fun getCode(email: String): String?

    fun markVerified(email: String, ttl: Duration)

    fun isVerified(email: String): Boolean

    fun deleteCode(email: String)

    fun deleteVerified(email: String)
}
