package com.nugusauce.domain.member

import org.springframework.data.jpa.repository.Query
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.repository.query.Param

interface ExternalIdentityRepository : JpaRepository<ExternalIdentity, Long> {
    fun findByProviderAndProviderSubject(
        provider: AuthProvider,
        providerSubject: String
    ): ExternalIdentity?

    fun findAllByMemberId(memberId: Long): List<ExternalIdentity>

    @Query("select count(distinct identity.member.id) from ExternalIdentity identity")
    fun countDistinctMemberIds(): Long

    @Query(
        """
        select identity.provider as provider, count(distinct identity.member.id) as memberCount
        from ExternalIdentity identity
        group by identity.provider
        """
    )
    fun countDistinctMemberIdsByProvider(): List<ExternalIdentityProviderCount>

    @Query(
        "select distinct identity.member.id from ExternalIdentity identity " +
            "where identity.member.id in :memberIds"
    )
    fun findDistinctMemberIdsByIdIn(@Param("memberIds") memberIds: Collection<Long>): Set<Long>
}
