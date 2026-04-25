package com.nugusauce.domain.member

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id

@Entity
class Member(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @Column(nullable = false, unique = true)
    val email: String,

    @Column(nullable = true)
    val passwordHash: String?,

    @Column(nullable = false)
    val role: String = "ROLE_USER",
)
