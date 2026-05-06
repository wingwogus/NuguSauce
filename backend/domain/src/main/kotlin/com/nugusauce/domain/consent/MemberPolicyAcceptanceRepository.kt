package com.nugusauce.domain.consent

import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param

interface MemberPolicyAcceptanceRepository : JpaRepository<MemberPolicyAcceptance, Long> {
    @Query(
        """
        select a
        from MemberPolicyAcceptance a
        join fetch a.policyVersion
        where a.member.id = :memberId
          and a.policyVersion.id in :policyVersionIds
        """
    )
    fun findByMemberIdAndPolicyVersionIds(
        @Param("memberId") memberId: Long,
        @Param("policyVersionIds") policyVersionIds: Collection<Long>
    ): List<MemberPolicyAcceptance>
}
