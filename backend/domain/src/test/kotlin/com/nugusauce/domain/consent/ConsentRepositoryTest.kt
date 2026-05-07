package com.nugusauce.domain.consent

import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import com.nugusauce.domain.media.MediaAsset
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.SpringBootConfiguration
import org.springframework.boot.autoconfigure.EnableAutoConfiguration
import org.springframework.boot.autoconfigure.domain.EntityScan
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest
import org.springframework.data.jpa.repository.config.EnableJpaRepositories
import org.springframework.test.context.ContextConfiguration
import java.time.Instant

@DataJpaTest
@ContextConfiguration(classes = [ConsentRepositoryTest.JpaTestApplication::class])
class ConsentRepositoryTest @Autowired constructor(
    private val memberRepository: MemberRepository,
    private val policyVersionRepository: PolicyVersionRepository,
    private val memberPolicyAcceptanceRepository: MemberPolicyAcceptanceRepository
) {
    @Test
    fun `findRequiredActiveAt returns active required policies only`() {
        val now = Instant.parse("2026-05-06T00:00:00Z")
        policyVersionRepository.save(
            policy(
                type = PolicyType.TERMS_OF_SERVICE,
                version = "2026-05-01",
                activeFrom = Instant.parse("2026-05-01T00:00:00Z")
            )
        )
        policyVersionRepository.save(
            policy(
                type = PolicyType.PRIVACY_POLICY,
                version = "2026-06-01",
                activeFrom = Instant.parse("2026-06-01T00:00:00Z")
            )
        )
        policyVersionRepository.save(
            policy(
                type = PolicyType.CONTENT_POLICY,
                version = "2026-05-01",
                required = false,
                activeFrom = Instant.parse("2026-05-01T00:00:00Z")
            )
        )

        val policies = policyVersionRepository.findRequiredActiveAt(now)

        assertEquals(listOf("2026-05-01"), policies.map { it.version })
        assertEquals(PolicyType.TERMS_OF_SERVICE, policies.first().policyType)
    }

    @Test
    fun `findByMemberIdAndPolicyVersionIds returns accepted policies for member`() {
        val member = memberRepository.save(Member(email = "user@example.test", passwordHash = null))
        val otherMember = memberRepository.save(Member(email = "other@example.test", passwordHash = null))
        val terms = policyVersionRepository.save(policy(PolicyType.TERMS_OF_SERVICE))
        val privacy = policyVersionRepository.save(policy(PolicyType.PRIVACY_POLICY))
        memberPolicyAcceptanceRepository.save(MemberPolicyAcceptance(member = member, policyVersion = terms))
        memberPolicyAcceptanceRepository.save(MemberPolicyAcceptance(member = otherMember, policyVersion = privacy))

        val accepted = memberPolicyAcceptanceRepository.findByMemberIdAndPolicyVersionIds(
            member.id,
            listOf(terms.id, privacy.id)
        )

        assertEquals(listOf(terms.id), accepted.map { it.policyVersion.id })
        assertTrue(accepted.all { it.member.id == member.id })
    }

    private fun policy(
        type: PolicyType,
        version: String = "2026-05-01",
        required: Boolean = true,
        activeFrom: Instant = Instant.parse("2026-05-01T00:00:00Z")
    ): PolicyVersion =
        PolicyVersion(
            policyType = type,
            version = version,
            title = type.wireValue,
            url = "nugusauce://legal/${type.wireValue}",
            required = required,
            activeFrom = activeFrom,
            createdAt = Instant.parse("2026-05-01T00:00:00Z")
        )

    @SpringBootConfiguration
    @EnableAutoConfiguration
    @EntityScan(
        basePackageClasses = [
            Member::class,
            MediaAsset::class,
            PolicyVersion::class,
            MemberPolicyAcceptance::class
        ]
    )
    @EnableJpaRepositories(
        basePackageClasses = [
            MemberRepository::class,
            PolicyVersionRepository::class,
            MemberPolicyAcceptanceRepository::class
        ]
    )
    class JpaTestApplication
}
