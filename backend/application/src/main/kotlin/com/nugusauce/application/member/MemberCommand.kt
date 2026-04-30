package com.nugusauce.application.member

object MemberCommand {
    data class UpdateMe(
        val memberId: Long,
        val nickname: String,
        val profileImageId: Long? = null
    )
}
