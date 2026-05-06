package com.nugusauce.domain.consent

import com.nugusauce.domain.member.Member
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import jakarta.persistence.UniqueConstraint
import java.time.Instant

@Entity
@Table(
    name = "member_policy_acceptance",
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_member_policy_acceptance_member_policy",
            columnNames = ["member_id", "policy_version_id"]
        )
    ]
)
class MemberPolicyAcceptance(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "policy_version_id", nullable = false)
    val policyVersion: PolicyVersion,

    @Column(nullable = false)
    val acceptedAt: Instant = Instant.now(),

    @Column(nullable = false, length = 40)
    val source: String = "ios"
) {
    init {
        require(source.isNotBlank()) { "policy acceptance source must not be blank" }
    }
}
