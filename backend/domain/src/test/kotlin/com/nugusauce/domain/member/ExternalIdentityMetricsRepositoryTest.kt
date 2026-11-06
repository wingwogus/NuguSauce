package com.nugusauce.domain.member

import com.nugusauce.domain.media.MediaAsset
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.SpringBootConfiguration
import org.springframework.boot.autoconfigure.EnableAutoConfiguration
import org.springframework.boot.autoconfigure.domain.EntityScan
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest
import org.springframework.data.jpa.repository.config.EnableJpaRepositories
import org.springframework.test.context.ContextConfiguration

@DataJpaTest
@ContextConfiguration(classes = [ExternalIdentityMetricsRepositoryTest.Config::class])
class ExternalIdentityMetricsRepositoryTest @Autowired constructor(
    private val members: MemberRepository,
    private val identities: ExternalIdentityRepository
) {
    @Test
    fun `deduplicates linked accounts excludes local members and filters session candidates`() {
        val both = members.save(Member(email = "both@example.test", passwordHash = null))
        val apple = members.save(Member(email = "apple@example.test", passwordHash = null))
        val kakao = members.save(Member(email = "kakao@example.test", passwordHash = null))
        val local = members.save(Member(email = "seed@example.test", passwordHash = "test-hash"))
        listOf(both to AuthProvider.APPLE, both to AuthProvider.KAKAO,
            apple to AuthProvider.APPLE, kakao to AuthProvider.KAKAO).forEachIndexed { i, (member, provider) ->
            identities.save(ExternalIdentity(member = member, provider = provider,
                providerSubject = "synthetic-$i", emailAtLinkTime = member.email))
        }
        identities.flush()

        assertEquals(3L, identities.countDistinctMemberIds())
        assertEquals(mapOf(AuthProvider.APPLE to 2L, AuthProvider.KAKAO to 2L),
            identities.countDistinctMemberIdsByProvider().associate { it.provider to it.memberCount })
        assertEquals(setOf(both.id, apple.id),
            identities.findDistinctMemberIdsByIdIn(listOf(both.id, apple.id, local.id, Long.MAX_VALUE)))
    }

    @Test
    fun `empty identity table has zero total and no provider groups`() {
        members.save(Member(email = "local-only@example.test", passwordHash = "test-hash"))
        assertEquals(0L, identities.countDistinctMemberIds())
        assertEquals(emptyList<ExternalIdentityProviderCount>(), identities.countDistinctMemberIdsByProvider())
    }

    @SpringBootConfiguration
    @EnableAutoConfiguration
    @EntityScan(basePackageClasses = [Member::class, MediaAsset::class])
    @EnableJpaRepositories(basePackageClasses = [MemberRepository::class])
    class Config
}
