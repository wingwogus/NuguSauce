package com.nugusauce.domain.member

import org.springframework.data.jpa.repository.JpaRepository

interface ExternalIdentityRepository : JpaRepository<ExternalIdentity, Long> {
    fun findByProviderAndProviderSubject(
        provider: AuthProvider,
        providerSubject: String
    ): ExternalIdentity?

    fun findAllByMemberId(memberId: Long): List<ExternalIdentity>
}
