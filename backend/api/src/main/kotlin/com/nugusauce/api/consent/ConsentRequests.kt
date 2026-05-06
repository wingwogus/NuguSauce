package com.nugusauce.api.consent

import com.nugusauce.application.consent.ConsentCommand
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotEmpty

object ConsentRequests {
    data class AcceptConsentsRequest(
        @field:NotEmpty
        @field:Valid
        val acceptedPolicies: List<PolicyAcceptanceRequest>
    ) {
        fun toCommand(memberId: Long): ConsentCommand.Accept {
            return ConsentCommand.Accept(
                memberId = memberId,
                acceptedPolicies = acceptedPolicies.map(PolicyAcceptanceRequest::toCommand)
            )
        }
    }

    data class PolicyAcceptanceRequest(
        @field:NotBlank
        val policyType: String,

        @field:NotBlank
        val version: String
    ) {
        fun toCommand(): ConsentCommand.PolicyAcceptance {
            return ConsentCommand.PolicyAcceptance(
                policyType = policyType,
                version = version
            )
        }
    }
}
