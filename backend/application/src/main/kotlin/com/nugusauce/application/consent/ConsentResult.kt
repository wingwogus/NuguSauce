package com.nugusauce.application.consent

import java.time.Instant

object ConsentResult {
    data class Status(
        val policies: List<PolicyStatus>,
        val missingPolicies: List<PolicyStatus>,
        val requiredConsentsAccepted: Boolean
    )

    data class PolicyStatus(
        val policyType: String,
        val version: String,
        val title: String,
        val url: String,
        val required: Boolean,
        val accepted: Boolean,
        val activeFrom: Instant
    )
}
