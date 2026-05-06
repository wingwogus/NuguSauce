package com.nugusauce.application.consent

object ConsentCommand {
    data class Accept(
        val memberId: Long,
        val acceptedPolicies: List<PolicyAcceptance>,
        val source: String = "ios"
    )

    data class PolicyAcceptance(
        val policyType: String,
        val version: String
    )
}
