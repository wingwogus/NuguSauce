package com.nugusauce.api.consent

import com.nugusauce.api.common.ApiResponse
import com.nugusauce.application.consent.ConsentService
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import jakarta.validation.Valid
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/consents")
class ConsentController(
    private val consentService: ConsentService
) {
    @GetMapping("/status")
    fun getStatus(
        @AuthenticationPrincipal userId: String?
    ): ResponseEntity<ApiResponse<ConsentResponses.ConsentStatusResponse>> {
        val status = consentService.status(requireUserId(userId))
        return ResponseEntity.ok(ApiResponse.ok(ConsentResponses.ConsentStatusResponse.from(status)))
    }

    @PostMapping("/accept")
    fun accept(
        @AuthenticationPrincipal userId: String?,
        @Valid @RequestBody request: ConsentRequests.AcceptConsentsRequest
    ): ResponseEntity<ApiResponse<ConsentResponses.ConsentStatusResponse>> {
        val status = consentService.accept(request.toCommand(requireUserId(userId)))
        return ResponseEntity.ok(ApiResponse.ok(ConsentResponses.ConsentStatusResponse.from(status)))
    }

    private fun requireUserId(userId: String?): Long {
        return userId?.toLongOrNull() ?: throw BusinessException(ErrorCode.UNAUTHORIZED)
    }
}
