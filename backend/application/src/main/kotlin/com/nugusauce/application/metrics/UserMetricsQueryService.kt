package com.nugusauce.application.metrics

import com.nugusauce.application.redis.RefreshTokenRepository
import com.nugusauce.domain.member.AuthProvider
import com.nugusauce.domain.member.ExternalIdentityRepository
import org.springframework.stereotype.Service

data class UserMetricsSnapshot(
    val registered: Long,
    val registeredByProvider: Map<String, Long>,
    val loggedIn: Long
)

@Service
class UserMetricsQueryService(
    private val externalIdentityRepository: ExternalIdentityRepository,
    private val refreshTokenRepository: RefreshTokenRepository
) {

    fun collect(): UserMetricsSnapshot {
        val registeredByProvider = externalIdentityRepository
            .countDistinctMemberIdsByProvider()
            .associate { it.provider.name to it.memberCount }

        val activeRefreshMemberIds = refreshTokenRepository.findActiveMemberIds()
        val loggedInMemberIds = activeRefreshMemberIds
            .chunked(DB_QUERY_BATCH_SIZE)
            .asSequence()
            .flatMap { memberIds ->
                externalIdentityRepository.findDistinctMemberIdsByIdIn(memberIds).asSequence()
            }
            .toSet()

        return UserMetricsSnapshot(
            registered = externalIdentityRepository.countDistinctMemberIds(),
            registeredByProvider = AuthProvider.entries.associate {
                it.name to (registeredByProvider[it.name] ?: 0L)
            },
            loggedIn = loggedInMemberIds.size.toLong()
        )
    }

    private companion object {
        const val DB_QUERY_BATCH_SIZE = 500
    }
}
