package com.nugusauce.application.redis

import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.data.redis.core.ValueOperations
import java.time.Duration
import java.util.concurrent.TimeUnit

class AppleNonceReplayRedisRepositoryTest {

    @Test
    fun `reserve stores apple nonce hash with millisecond ttl`() {
        val redis = org.mockito.Mockito.mock(StringRedisTemplate::class.java)
        @Suppress("UNCHECKED_CAST")
        val valueOperations = org.mockito.Mockito.mock(ValueOperations::class.java) as ValueOperations<String, String>
        val repository = AppleNonceReplayRedisRepository(redis)

        `when`(redis.opsForValue()).thenReturn(valueOperations)
        `when`(
            valueOperations.setIfAbsent(
                org.mockito.Mockito.eq("auth:apple:nonce:nonce-hash"),
                org.mockito.Mockito.eq("1"),
                org.mockito.Mockito.eq(500L),
                org.mockito.Mockito.eq(TimeUnit.MILLISECONDS)
            )
        ).thenReturn(true)

        val reserved = repository.reserve("nonce-hash", Duration.ofMillis(500))

        assertTrue(reserved)
        verify(valueOperations).setIfAbsent(
            org.mockito.Mockito.eq("auth:apple:nonce:nonce-hash"),
            org.mockito.Mockito.eq("1"),
            org.mockito.Mockito.eq(500L),
            org.mockito.Mockito.eq(TimeUnit.MILLISECONDS)
        )
    }

    @Test
    fun `reserve rejects non-positive ttl`() {
        val redis = org.mockito.Mockito.mock(StringRedisTemplate::class.java)
        val repository = AppleNonceReplayRedisRepository(redis)

        assertFalse(repository.reserve("nonce-hash", Duration.ZERO))
    }
}
