package com.nugusauce.api.consent

import com.nugusauce.application.consent.ConsentResult
import java.time.Instant

object ConsentResponses {
    data class ConsentStatusResponse(
        val policies: List<PolicyResponse>,
        val missingPolicies: List<PolicyResponse>,
        val requiredConsentsAccepted: Boolean
    ) {
        companion object {
            fun from(result: ConsentResult.Status): ConsentStatusResponse =
                ConsentStatusResponse(
                    policies = result.policies.map(PolicyResponse::from),
                    missingPolicies = result.missingPolicies.map(PolicyResponse::from),
                    requiredConsentsAccepted = result.requiredConsentsAccepted
                )
        }
    }

    data class PolicyResponse(
        val policyType: String,
        val version: String,
        val title: String,
        val url: String,
        val required: Boolean,
        val accepted: Boolean,
        val activeFrom: Instant
    ) {
        companion object {
            fun from(result: ConsentResult.PolicyStatus): PolicyResponse =
                PolicyResponse(
                    policyType = result.policyType,
                    version = result.version,
                    title = result.title,
                    url = result.url,
                    required = result.required,
                    accepted = result.accepted,
                    activeFrom = result.activeFrom
                )
        }
    }
}
