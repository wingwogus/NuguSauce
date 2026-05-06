package com.nugusauce.application.consent

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.domain.consent.MemberPolicyAcceptance
import com.nugusauce.domain.consent.MemberPolicyAcceptanceRepository
import com.nugusauce.domain.consent.PolicyType
import com.nugusauce.domain.consent.PolicyVersion
import com.nugusauce.domain.consent.PolicyVersionRepository
import com.nugusauce.domain.member.MemberRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Instant

@Service
class ConsentService(
    private val policyVersionRepository: PolicyVersionRepository,
    private val memberPolicyAcceptanceRepository: MemberPolicyAcceptanceRepository,
    private val memberRepository: MemberRepository,
    private val clock: Clock = Clock.systemUTC()
) {
    @Transactional(readOnly = true)
    fun status(memberId: Long): ConsentResult.Status {
        requireMember(memberId)
        val currentPolicies = currentRequiredPolicies()
        val acceptedPolicyIds = acceptedPolicyIds(memberId, currentPolicies)
        return buildStatus(currentPolicies, acceptedPolicyIds)
    }

    @Transactional
    fun accept(command: ConsentCommand.Accept): ConsentResult.Status {
        val member = requireMember(command.memberId)
        val currentPolicies = currentRequiredPolicies()
        val currentByKey = currentPolicies.associateBy { it.policyType to it.version }
        val requestedKeys = command.acceptedPolicies.map { acceptance ->
            val policyType = PolicyType.fromWireValue(acceptance.policyType)
                ?: throw BusinessException(
                    ErrorCode.INVALID_INPUT,
                    detail = mapOf("field" to "policyType", "reason" to "unsupported policy type")
                )
            policyType to acceptance.version.trim()
        }.toSet()
        val invalidKeys = requestedKeys - currentByKey.keys

        if (requestedKeys.isEmpty() || invalidKeys.isNotEmpty()) {
            throw BusinessException(
                ErrorCode.INVALID_INPUT,
                detail = mapOf(
                    "field" to "acceptedPolicies",
                    "reason" to "must contain current required policy versions",
                    "invalidPolicies" to invalidKeys.map { "${it.first.wireValue}:${it.second}" }
                )
            )
        }

        val acceptedPolicyIds = acceptedPolicyIds(command.memberId, currentPolicies).toMutableSet()
        val newlyAccepted = requestedKeys
            .mapNotNull(currentByKey::get)
            .filterNot { it.id in acceptedPolicyIds }

        if (newlyAccepted.isNotEmpty()) {
            memberPolicyAcceptanceRepository.saveAll(
                newlyAccepted.map {
                    MemberPolicyAcceptance(
                        member = member,
                        policyVersion = it,
                        source = command.source.trim().ifEmpty { "ios" }
                    )
                }
            )
            acceptedPolicyIds += newlyAccepted.map { it.id }
        }

        return buildStatus(currentPolicies, acceptedPolicyIds)
    }

    @Transactional(readOnly = true)
    fun requireRequiredConsents(memberId: Long) {
        val status = status(memberId)
        if (status.requiredConsentsAccepted) {
            return
        }

        throw BusinessException(
            ErrorCode.CONSENT_REQUIRED,
            detail = mapOf(
                "missingPolicies" to status.missingPolicies.map {
                    mapOf(
                        "policyType" to it.policyType,
                        "version" to it.version,
                        "title" to it.title,
                        "url" to it.url
                    )
                }
            )
        )
    }

    private fun requireMember(memberId: Long) =
        memberRepository.findById(memberId).orElseThrow { BusinessException(ErrorCode.USER_NOT_FOUND) }

    private fun currentRequiredPolicies(): List<PolicyVersion> {
        val policies = policyVersionRepository
            .findRequiredActiveAt(Instant.now(clock))
            .distinctBy { it.policyType }
        val missingTypes = REQUIRED_POLICY_TYPES - policies.map { it.policyType }.toSet()

        if (missingTypes.isNotEmpty()) {
            throw BusinessException(
                ErrorCode.CONSENT_REQUIRED,
                detail = mapOf(
                    "reason" to "required policy versions are not configured",
                    "missingPolicyTypes" to missingTypes.map { it.wireValue }
                )
            )
        }

        return policies
    }

    private fun acceptedPolicyIds(memberId: Long, policies: List<PolicyVersion>): Set<Long> {
        val policyIds = policies.map { it.id }
        if (policyIds.isEmpty()) {
            return emptySet()
        }
        return memberPolicyAcceptanceRepository
            .findByMemberIdAndPolicyVersionIds(memberId, policyIds)
            .map { it.policyVersion.id }
            .toSet()
    }

    private fun buildStatus(
        policies: List<PolicyVersion>,
        acceptedPolicyIds: Set<Long>
    ): ConsentResult.Status {
        val statuses = policies.map { policy ->
            ConsentResult.PolicyStatus(
                policyType = policy.policyType.wireValue,
                version = policy.version,
                title = policy.title,
                url = policy.url,
                required = policy.required,
                accepted = policy.id in acceptedPolicyIds,
                activeFrom = policy.activeFrom
            )
        }
        val missingPolicies = statuses.filter { it.required && !it.accepted }
        return ConsentResult.Status(
            policies = statuses,
            missingPolicies = missingPolicies,
            requiredConsentsAccepted = missingPolicies.isEmpty()
        )
    }

    private companion object {
        val REQUIRED_POLICY_TYPES = PolicyType.values().toSet()
    }
}
