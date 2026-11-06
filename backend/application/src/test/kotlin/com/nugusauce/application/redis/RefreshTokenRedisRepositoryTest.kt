package com.nugusauce.application.redis

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.mockito.ArgumentMatchers.any
import org.mockito.Mockito.*
import org.springframework.data.redis.connection.RedisConnection
import org.springframework.data.redis.connection.RedisKeyCommands
import org.springframework.data.redis.core.Cursor
import org.springframework.data.redis.core.RedisCallback
import org.springframework.data.redis.core.ScanOptions
import org.springframework.data.redis.core.StringRedisTemplate

class RefreshTokenRedisRepositoryTest {
    private val redis = mock(StringRedisTemplate::class.java)
    private val connection = mock(RedisConnection::class.java)
    private val commands = mock(RedisKeyCommands::class.java)
    private val repository = RefreshTokenRedisRepository(redis)

    @Test
    fun `counts canonical ids once with positive ttl without reading token values`() {
        val cursor = scan(listOf("refresh:1", "refresh:1", "refresh:001", "refresh:2", "refresh:3",
            "refresh:4", "refresh:5", "refresh:0", "refresh:-1", "refresh:x", "refresh:",
            "refresh:9223372036854775808", "other:3"))
        `when`(commands.pTtl("refresh:1".toByteArray())).thenReturn(10L)
        `when`(commands.pTtl("refresh:2".toByteArray())).thenReturn(-2L)
        `when`(commands.pTtl("refresh:3".toByteArray())).thenReturn(0L)
        `when`(commands.pTtl("refresh:4".toByteArray())).thenReturn(-1L)
        `when`(commands.pTtl("refresh:5".toByteArray())).thenReturn(100L)

        assertEquals(setOf(1L, 5L), repository.findActiveMemberIds())
        verify(commands, times(1)).pTtl("refresh:1".toByteArray())
        verify(cursor).close()
        verify(redis, never()).opsForValue()
    }

    @Test
    fun `bounds duplicate scan work and closes the cursor on failure`() {
        val cursor = scan(List(10_001) { "refresh:1" })
        `when`(commands.pTtl("refresh:1".toByteArray())).thenReturn(10L)
        assertThrows(IllegalStateException::class.java) { repository.findActiveMemberIds() }
        verify(cursor).close()
    }

    @Test
    fun `redis failures propagate instead of publishing zero`() {
        `when`(redis.execute<Set<Long>>(any<RedisCallback<Set<Long>>>()))
            .thenThrow(IllegalStateException("unavailable"))
        assertThrows(IllegalStateException::class.java) { repository.findActiveMemberIds() }
    }

    @Test
    fun `missing redis result is a failed collection instead of zero`() {
        assertThrows(IllegalStateException::class.java) { repository.findActiveMemberIds() }
    }

    private fun scan(keys: List<String>): Cursor<ByteArray> {
        @Suppress("UNCHECKED_CAST")
        val cursor = mock(Cursor::class.java) as Cursor<ByteArray>
        val iterator = keys.map { it.toByteArray() }.iterator()
        `when`(cursor.hasNext()).thenAnswer { iterator.hasNext() }
        `when`(cursor.next()).thenAnswer { iterator.next() }
        `when`(redis.execute<Set<Long>>(any<RedisCallback<Set<Long>>>())).thenAnswer { invocation ->
            invocation.getArgument<RedisCallback<Set<Long>>>(0).doInRedis(connection)
        }
        `when`(connection.keyCommands()).thenReturn(commands)
        `when`(commands.scan(any(ScanOptions::class.java))).thenReturn(cursor)
        return cursor
    }
}
