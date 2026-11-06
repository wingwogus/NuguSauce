package com.nugusauce.application.redis

import org.springframework.data.redis.connection.RedisConnection
import org.springframework.data.redis.core.ScanOptions
import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.stereotype.Repository
import java.nio.charset.StandardCharsets
import java.util.concurrent.TimeUnit

@Repository
class RefreshTokenRedisRepository(
    private val redis: StringRedisTemplate
) : RefreshTokenRepository {

    companion object {
        private const val PREFIX = "refresh:"
        private const val SCAN_COUNT = 256L
        private const val MAX_SCANNED_KEYS = 10_000
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

    override fun findActiveMemberIds(): Set<Long> {
        return redis.execute<Set<Long>> { connection ->
            scanActiveMemberIds(connection)
        } ?: error("refresh session scan did not complete")
    }

    private fun scanActiveMemberIds(connection: RedisConnection): Set<Long> {
        val activeMemberIds = linkedSetOf<Long>()
        val seenKeys = hashSetOf<String>()
        var scannedKeys = 0
        val scanOptions = ScanOptions.scanOptions()
            .match("$PREFIX*")
            .count(SCAN_COUNT)
            .build()

        connection.keyCommands().scan(scanOptions).use { cursor ->
            while (cursor.hasNext()) {
                if (scannedKeys >= MAX_SCANNED_KEYS) {
                    throw IllegalStateException("refresh key scan exceeded safety limit")
                }

                val key = String(cursor.next(), StandardCharsets.UTF_8)
                scannedKeys++
                if (!seenKeys.add(key)) {
                    continue
                }

                val memberId = parseMemberId(key) ?: continue
                val remainingMillis = connection.keyCommands().pTtl(key.toByteArray(StandardCharsets.UTF_8))
                if (remainingMillis != null && remainingMillis > 0) {
                    activeMemberIds += memberId
                }
            }
        }

        return activeMemberIds
    }

    private fun parseMemberId(key: String): Long? {
        if (!key.startsWith(PREFIX)) {
            return null
        }

        val suffix = key.removePrefix(PREFIX)
        if (suffix.isEmpty() || suffix.length > 1 && suffix.startsWith('0') || suffix.any { it !in '0'..'9' }) {
            return null
        }

        return suffix.toLongOrNull()?.takeIf { it > 0 }
    }
}
