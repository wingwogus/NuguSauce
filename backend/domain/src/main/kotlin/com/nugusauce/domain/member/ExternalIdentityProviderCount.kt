package com.nugusauce.domain.member

interface ExternalIdentityProviderCount {
    val provider: AuthProvider
    val memberCount: Long
}
