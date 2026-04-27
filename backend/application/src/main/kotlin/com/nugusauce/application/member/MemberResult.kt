package com.nugusauce.application.member

import com.nugusauce.domain.member.Member

object MemberResult {
    data class Me(
        val id: Long,
        val nickname: String?,
        val displayName: String,
        val profileSetupRequired: Boolean
    )

    data class PublicProfile(
        val id: Long,
        val nickname: String?,
        val displayName: String
    )

    fun me(member: Member): Me {
        return Me(
            id = member.id,
            nickname = member.nickname,
            displayName = displayName(member),
            profileSetupRequired = member.nickname.isNullOrBlank()
        )
    }

    fun publicProfile(member: Member): PublicProfile {
        return PublicProfile(
            id = member.id,
            nickname = member.nickname,
            displayName = displayName(member)
        )
    }

    fun displayName(member: Member): String {
        return member.nickname ?: "사용자 ${member.id}"
    }
}
