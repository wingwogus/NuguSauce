package com.nugusauce.api.member

import com.nugusauce.application.member.MemberResult

object MemberResponses {
    data class MeResponse(
        val id: Long,
        val nickname: String?,
        val displayName: String,
        val profileSetupRequired: Boolean
    ) {
        companion object {
            fun from(result: MemberResult.Me): MeResponse {
                return MeResponse(
                    id = result.id,
                    nickname = result.nickname,
                    displayName = result.displayName,
                    profileSetupRequired = result.profileSetupRequired
                )
            }
        }
    }

    data class PublicProfileResponse(
        val id: Long,
        val nickname: String?,
        val displayName: String
    ) {
        companion object {
            fun from(result: MemberResult.PublicProfile): PublicProfileResponse {
                return PublicProfileResponse(
                    id = result.id,
                    nickname = result.nickname,
                    displayName = result.displayName
                )
            }
        }
    }
}
