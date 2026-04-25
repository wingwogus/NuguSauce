package com.nugusauce.application.auth

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.redis.KakaoNonceReplayRepository
import com.nugusauce.application.redis.RefreshTokenRepository
import com.nugusauce.application.security.KakaoOidcClaims
import com.nugusauce.application.security.KakaoOidcTokenVerifier
import com.nugusauce.application.security.KakaoUserInfoClient
import com.nugusauce.application.security.TokenProvider
import com.nugusauce.domain.member.AuthProvider
import com.nugusauce.domain.member.ExternalIdentity
import com.nugusauce.domain.member.ExternalIdentityRepository
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Duration
import java.time.Instant

@Service
@Transactional
class KakaoLoginService(
    private val kakaoOidcTokenVerifier: KakaoOidcTokenVerifier,
    private val kakaoUserInfoClient: KakaoUserInfoClient,
    private val kakaoNonceReplayRepository: KakaoNonceReplayRepository,
    private val externalIdentityRepository: ExternalIdentityRepository,
    private val memberRepository: MemberRepository,
    private val tokenProvider: TokenProvider,
    private val refreshTokenRepository: RefreshTokenRepository,
    @Value("\${auth.kakao.oidc.nonce-replay-ttl-seconds:600}")
    nonceReplayTtlSeconds: Long,
    @Value("\${auth.kakao.oidc.allowed-clock-skew-seconds:60}")
    allowedClockSkewSeconds: Long
) {
    private val maxNonceReplayTtl = Duration.ofSeconds(nonceReplayTtlSeconds)
    private val allowedClockSkew = Duration.ofSeconds(allowedClockSkewSeconds)

    fun login(command: AuthCommand.KakaoLogin): AuthResult.TokenPair {
        val claims = kakaoOidcTokenVerifier.verify(command.idToken, command.nonce)
        reserveNonce(claims)

        val member = externalIdentityRepository
            .findByProviderAndProviderSubject(AuthProvider.KAKAO, claims.subject)
            ?.member
            ?: linkOrCreateMember(claims, command.kakaoAccessToken)

        return issueAndStoreTokens(member)
    }

    private fun reserveNonce(claims: KakaoOidcClaims) {
        val ttl = nonceReplayTtl(claims.expiresAt)
        if (!kakaoNonceReplayRepository.reserve(claims.nonce, ttl)) {
            throw BusinessException(ErrorCode.KAKAO_NONCE_REPLAY)
        }
    }

    private fun nonceReplayTtl(expiresAt: Instant): Duration {
        val acceptedUntil = expiresAt.plus(allowedClockSkew)
        val untilExpiry = Duration.between(Instant.now(), acceptedUntil)
        if (untilExpiry <= Duration.ZERO) {
            throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)
        }
        return if (untilExpiry < maxNonceReplayTtl) untilExpiry else maxNonceReplayTtl
    }

    private fun linkOrCreateMember(claims: KakaoOidcClaims, accessToken: String?): Member {
        val email = verifiedEmailFromClaims(claims)
            ?: verifiedEmailFromUserInfo(claims, accessToken)
            ?: throw BusinessException(ErrorCode.KAKAO_VERIFIED_EMAIL_REQUIRED)

        val member = memberRepository.findByEmail(email)
            ?: memberRepository.save(
                Member(
                    email = email,
                    passwordHash = null
                )
            )

        externalIdentityRepository.save(
            ExternalIdentity(
                member = member,
                provider = AuthProvider.KAKAO,
                providerSubject = claims.subject,
                emailAtLinkTime = email
            )
        )

        return member
    }

    private fun verifiedEmailFromClaims(claims: KakaoOidcClaims): String? {
        return claims.email?.takeIf { it.isNotBlank() && claims.emailVerified }
    }

    private fun verifiedEmailFromUserInfo(claims: KakaoOidcClaims, accessToken: String?): String? {
        val token = accessToken?.takeIf { it.isNotBlank() }
            ?: return null
        val userInfo = kakaoUserInfoClient.fetch(token)
        if (userInfo.subject != claims.subject) {
            throw BusinessException(ErrorCode.INVALID_KAKAO_TOKEN)
        }
        return userInfo.email?.takeIf { it.isNotBlank() && userInfo.emailVerified }
    }

    private fun issueAndStoreTokens(member: Member): AuthResult.TokenPair {
        val tokenPair = tokenProvider.generateToken(member.id, member.role)
        refreshTokenRepository.save(
            member.id,
            tokenPair.refreshToken,
            tokenProvider.getRefreshTokenValiditySeconds()
        )
        return tokenPair
    }
}
