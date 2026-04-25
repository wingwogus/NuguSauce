package com.nugusauce.api.auth

import com.fasterxml.jackson.annotation.JsonProperty
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.security.KakaoUserInfo
import com.nugusauce.application.security.KakaoUserInfoClient
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import org.springframework.web.client.RestClient
import org.springframework.web.client.RestClientException
import org.springframework.web.client.RestClientResponseException

@Component
class KakaoOidcUserInfoHttpClient(
    restClientBuilder: RestClient.Builder,
    @Value("\${auth.kakao.oidc.user-info-uri:https://kapi.kakao.com/v1/oidc/userinfo}")
    private val userInfoUri: String
) : KakaoUserInfoClient {
    private val restClient = restClientBuilder.build()

    override fun fetch(accessToken: String): KakaoUserInfo {
        val response = try {
            restClient
                .get()
                .uri(userInfoUri)
                .headers { headers -> headers.setBearerAuth(accessToken) }
                .retrieve()
                .body(KakaoOidcUserInfoResponse::class.java)
        } catch (exception: RestClientResponseException) {
            throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)
        } catch (exception: RestClientException) {
            throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)
        } ?: throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)

        val subject = response.subject?.takeIf { it.isNotBlank() }
            ?: throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)

        return KakaoUserInfo(
            subject = subject,
            email = response.email,
            emailVerified = response.emailVerified == true
        )
    }
}

private data class KakaoOidcUserInfoResponse(
    @JsonProperty("sub")
    val subject: String?,
    val email: String?,
    @JsonProperty("email_verified")
    val emailVerified: Boolean?
)
