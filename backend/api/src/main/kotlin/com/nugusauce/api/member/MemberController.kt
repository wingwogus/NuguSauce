package com.nugusauce.api.member

import com.nugusauce.api.common.ApiResponse
import com.nugusauce.application.consent.ConsentService
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.member.MemberCommand
import com.nugusauce.application.member.MemberService
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/members")
class MemberController(
    private val memberService: MemberService,
    private val consentService: ConsentService
) {
    @GetMapping("/me")
    fun getMe(
        @AuthenticationPrincipal userId: String?
    ): ResponseEntity<ApiResponse<MemberResponses.MeResponse>> {
        val result = memberService.getMe(requireUserId(userId))
        return ResponseEntity.ok(ApiResponse.ok(MemberResponses.MeResponse.from(result)))
    }

    @PatchMapping("/me")
    fun updateMe(
        @AuthenticationPrincipal userId: String?,
        @RequestBody request: MemberRequests.UpdateMeRequest
    ): ResponseEntity<ApiResponse<MemberResponses.MeResponse>> {
        val memberId = requireUserId(userId)
        if (request.profileImageId != null) {
            consentService.requireRequiredConsents(memberId)
        }
        val result = memberService.updateMe(
            MemberCommand.UpdateMe(
                memberId = memberId,
                nickname = request.nickname,
                profileImageId = request.profileImageId
            )
        )
        return ResponseEntity.ok(ApiResponse.ok(MemberResponses.MeResponse.from(result)))
    }

    @GetMapping("/{memberId}")
    fun getMember(
        @PathVariable memberId: Long
    ): ResponseEntity<ApiResponse<MemberResponses.PublicProfileResponse>> {
        val result = memberService.getPublicProfile(memberId)
        return ResponseEntity.ok(ApiResponse.ok(MemberResponses.PublicProfileResponse.from(result)))
    }

    private fun requireUserId(userId: String?): Long {
        return userId?.toLongOrNull() ?: throw BusinessException(ErrorCode.UNAUTHORIZED)
    }
}
