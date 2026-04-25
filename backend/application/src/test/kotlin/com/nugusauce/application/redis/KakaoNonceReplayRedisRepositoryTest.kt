package com.nugusauce.application.redis

import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.data.redis.core.ValueOperations
import java.time.Duration
import java.util.concurrent.TimeUnit

class KakaoNonceReplayRedisRepositoryTest {

    @Test
    fun `reserve uses millisecond ttl for sub-second accepted window`() {
        val redis = org.mockito.Mockito.mock(StringRedisTemplate::class.java)
        @Suppress("UNCHECKED_CAST")
        val valueOperations = org.mockito.Mockito.mock(ValueOperations::class.java) as ValueOperations<String, String>
        val repository = KakaoNonceReplayRedisRepository(redis)

        `when`(redis.opsForValue()).thenReturn(valueOperations)
        `when`(
            valueOperations.setIfAbsent(
                org.mockito.Mockito.anyString(),
                org.mockito.Mockito.eq("1"),
                org.mockito.Mockito.eq(500L),
                org.mockito.Mockito.eq(TimeUnit.MILLISECONDS)
            )
        ).thenReturn(true)

        val reserved = repository.reserve("nonce", Duration.ofMillis(500))

        assertTrue(reserved)
        verify(valueOperations).setIfAbsent(
            org.mockito.Mockito.anyString(),
            org.mockito.Mockito.eq("1"),
            org.mockito.Mockito.eq(500L),
            org.mockito.Mockito.eq(TimeUnit.MILLISECONDS)
        )
    }
}
