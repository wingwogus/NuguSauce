package com.nugusauce.application.metrics

import com.nugusauce.application.redis.RefreshTokenRepository
import com.nugusauce.domain.member.AuthProvider
import com.nugusauce.domain.member.ExternalIdentityProviderCount
import com.nugusauce.domain.member.ExternalIdentityRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.mockito.Mockito.never

class UserMetricsQueryServiceTest {

    private val externalIdentityRepository = mock(ExternalIdentityRepository::class.java)
    private val refreshTokenRepository = mock(RefreshTokenRepository::class.java)
    private val service = UserMetricsQueryService(externalIdentityRepository, refreshTokenRepository)

    @Test
    fun `collects provider counts and logs in only social members in active refresh sessions`() {
        `when`(externalIdentityRepository.countDistinctMemberIds()).thenReturn(3L)
        `when`(externalIdentityRepository.countDistinctMemberIdsByProvider()).thenReturn(
            listOf(
                providerCount(AuthProvider.APPLE, 2L),
                providerCount(AuthProvider.KAKAO, 2L)
            )
        )
        `when`(refreshTokenRepository.findActiveMemberIds()).thenReturn((1L..501L).toSet())
        `when`(externalIdentityRepository.findDistinctMemberIdsByIdIn((1L..500L).toList()))
            .thenReturn(setOf(1L, 2L))
        `when`(externalIdentityRepository.findDistinctMemberIdsByIdIn(listOf(501L)))
            .thenReturn(setOf(501L))

        assertEquals(
            UserMetricsSnapshot(
                registered = 3L,
                registeredByProvider = mapOf("APPLE" to 2L, "KAKAO" to 2L),
                loggedIn = 3L
            ),
            service.collect()
        )
        verify(externalIdentityRepository).findDistinctMemberIdsByIdIn((1L..500L).toList())
        verify(externalIdentityRepository).findDistinctMemberIdsByIdIn(listOf(501L))
    }

    @Test
    fun `does not query database for an empty refresh scan`() {
        `when`(externalIdentityRepository.countDistinctMemberIds()).thenReturn(0L)
        `when`(externalIdentityRepository.countDistinctMemberIdsByProvider()).thenReturn(emptyList())
        `when`(refreshTokenRepository.findActiveMemberIds()).thenReturn(emptySet())

        assertEquals(UserMetricsSnapshot(0L, mapOf("APPLE" to 0L, "KAKAO" to 0L), 0L), service.collect())
        verify(externalIdentityRepository, never()).findDistinctMemberIdsByIdIn(emptyList())
    }

    private fun providerCount(provider: AuthProvider, count: Long) = object : ExternalIdentityProviderCount {
        override val provider = provider
        override val memberCount = count
    }
}
