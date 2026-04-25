package com.nugusauce.domain.member

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import jakarta.persistence.UniqueConstraint

@Entity
@Table(
    name = "external_identity",
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_external_identity_provider_subject",
            columnNames = ["provider", "provider_subject"]
        )
    ]
)
class ExternalIdentity(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    val provider: AuthProvider,

    @Column(name = "provider_subject", nullable = false, length = 128)
    val providerSubject: String,

    @Column(name = "email_at_link_time", nullable = false)
    val emailAtLinkTime: String
)
