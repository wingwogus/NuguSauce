package com.nugusauce.domain.consent

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.Table
import jakarta.persistence.UniqueConstraint
import java.time.Instant

@Entity
@Table(
    name = "policy_version",
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_policy_version_type_version",
            columnNames = ["policy_type", "version"]
        )
    ]
)
class PolicyVersion(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @Enumerated(EnumType.STRING)
    @Column(name = "policy_type", nullable = false, length = 40)
    val policyType: PolicyType,

    @Column(nullable = false, length = 64)
    val version: String,

    @Column(nullable = false, length = 120)
    val title: String,

    @Column(nullable = false, length = 512)
    val url: String,

    @Column(nullable = false)
    val required: Boolean = true,

    @Column(nullable = false)
    val activeFrom: Instant = Instant.now(),

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
) {
    init {
        require(version.isNotBlank()) { "policy version must not be blank" }
        require(title.isNotBlank()) { "policy title must not be blank" }
        require(url.isNotBlank()) { "policy url must not be blank" }
    }
}
