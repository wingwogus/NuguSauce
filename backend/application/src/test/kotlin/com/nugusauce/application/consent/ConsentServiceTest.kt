package com.nugusauce.application.consent

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.domain.consent.MemberPolicyAcceptance
import com.nugusauce.domain.consent.MemberPolicyAcceptanceRepository
import com.nugusauce.domain.consent.PolicyType
import com.nugusauce.domain.consent.PolicyVersion
import com.nugusauce.domain.consent.PolicyVersionRepository
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.ArgumentMatchers.anyCollection
import org.mockito.Mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class ConsentServiceTest {
    @Mock
    private lateinit var policyVersionRepository: PolicyVersionRepository

    @Mock
    private lateinit var memberPolicyAcceptanceRepository: MemberPolicyAcceptanceRepository

    @Mock
    private lateinit var memberRepository: MemberRepository

    private lateinit var service: ConsentService

    @BeforeEach
    fun setUp() {
        service = ConsentService(
            policyVersionRepository,
            memberPolicyAcceptanceRepository,
            memberRepository,
            Clock.fixed(NOW, ZoneOffset.UTC)
        )
    }

    @Test
    fun `status marks missing active required policies`() {
        val member = member()
        val policies = currentPolicies()
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(policyVersionRepository.findRequiredActiveAt(NOW)).thenReturn(policies)
        `when`(memberPolicyAcceptanceRepository.findByMemberIdAndPolicyVersionIds(1L, policies.map { it.id }))
            .thenReturn(listOf(MemberPolicyAcceptance(member = member, policyVersion = policies.first())))

        val status = service.status(1L)

        assertFalse(status.requiredConsentsAccepted)
        assertEquals(listOf("privacy_policy", "content_policy"), status.missingPolicies.map { it.policyType })
    }

    @Test
    fun `accept records current policy version and returns updated status`() {
        val member = member()
        val policies = currentPolicies()
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(policyVersionRepository.findRequiredActiveAt(NOW)).thenReturn(policies)
        `when`(memberPolicyAcceptanceRepository.findByMemberIdAndPolicyVersionIds(1L, policies.map { it.id }))
            .thenReturn(emptyList())

        val status = service.accept(
            ConsentCommand.Accept(
                memberId = 1L,
                acceptedPolicies = policies.map {
                    ConsentCommand.PolicyAcceptance(policyType = it.policyType.wireValue, version = it.version)
                }
            )
        )

        assertTrue(status.requiredConsentsAccepted)
        verify(memberPolicyAcceptanceRepository).saveAll(anyCollection<MemberPolicyAcceptance>())
    }

    @Test
    fun `requireRequiredConsents throws stable consent error when a policy is missing`() {
        val member = member()
        val policies = currentPolicies()
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(policyVersionRepository.findRequiredActiveAt(NOW)).thenReturn(policies)
        `when`(memberPolicyAcceptanceRepository.findByMemberIdAndPolicyVersionIds(1L, policies.map { it.id }))
            .thenReturn(listOf(MemberPolicyAcceptance(member = member, policyVersion = policies.first())))

        val exception = assertThrows(BusinessException::class.java) {
            service.requireRequiredConsents(1L)
        }

        assertEquals(ErrorCode.CONSENT_REQUIRED, exception.errorCode)
    }

    @Test
    fun `accept rejects stale policy version`() {
        val policies = currentPolicies()
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member()))
        `when`(policyVersionRepository.findRequiredActiveAt(NOW)).thenReturn(policies)

        val exception = assertThrows(BusinessException::class.java) {
            service.accept(
                ConsentCommand.Accept(
                    memberId = 1L,
                    acceptedPolicies = listOf(
                        ConsentCommand.PolicyAcceptance(
                            policyType = PolicyType.TERMS_OF_SERVICE.wireValue,
                            version = "2025-01-01"
                        )
                    )
                )
            )
        }

        assertEquals(ErrorCode.INVALID_INPUT, exception.errorCode)
    }

    private fun member() = Member(1L, "user@example.test", null)

    private fun currentPolicies(): List<PolicyVersion> =
        listOf(
            policy(1L, PolicyType.TERMS_OF_SERVICE, "서비스 이용약관"),
            policy(2L, PolicyType.PRIVACY_POLICY, "개인정보 처리방침"),
            policy(3L, PolicyType.CONTENT_POLICY, "콘텐츠/사진 권리 정책")
        )

    private fun policy(id: Long, type: PolicyType, title: String): PolicyVersion =
        PolicyVersion(
            id = id,
            policyType = type,
            version = "2026-05-01",
            title = title,
            url = "nugusauce://legal/${type.wireValue}",
            activeFrom = Instant.parse("2026-05-01T00:00:00Z"),
            createdAt = Instant.parse("2026-05-01T00:00:00Z")
        )

    private companion object {
        val NOW: Instant = Instant.parse("2026-05-06T00:00:00Z")
    }
}
