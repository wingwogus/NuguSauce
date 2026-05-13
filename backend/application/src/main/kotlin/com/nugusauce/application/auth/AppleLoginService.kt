package com.nugusauce.application.auth

import com.nugusauce.application.consent.ConsentService
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.application.member.MemberResult
import com.nugusauce.application.redis.AppleNonceReplayRepository
import com.nugusauce.application.redis.RefreshTokenRepository
import com.nugusauce.application.security.AppleOidcClaims
import com.nugusauce.application.security.AppleRefreshTokenCipher
import com.nugusauce.application.security.AppleOidcTokenVerifier
import com.nugusauce.application.security.TokenProvider
import com.nugusauce.domain.member.AuthProvider
import com.nugusauce.domain.member.ExternalIdentity
import com.nugusauce.domain.member.ExternalIdentityRepository
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import mu.KotlinLogging
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Duration
import java.time.Instant

@Service
@Transactional
class AppleLoginService(
    private val appleOidcTokenVerifier: AppleOidcTokenVerifier,
    private val appleNonceReplayRepository: AppleNonceReplayRepository,
    private val externalIdentityRepository: ExternalIdentityRepository,
    private val memberRepository: MemberRepository,
    private val consentService: ConsentService,
    private val tokenProvider: TokenProvider,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val imageUrlResolver: ImageUrlResolver,
    private val appleTokenPort: AppleTokenPort,
    private val appleRefreshTokenCipher: AppleRefreshTokenCipher,
    @Value("\${auth.apple.oidc.allowed-clock-skew-seconds:60}")
    allowedClockSkewSeconds: Long
) {
    private val allowedClockSkew = Duration.ofSeconds(allowedClockSkewSeconds)

    fun login(command: AuthCommand.AppleLogin): AuthResult.SocialLogin {
        val claims = appleOidcTokenVerifier.verify(command.identityToken, command.nonce)
        if (!command.userIdentifier.isNullOrBlank() && command.userIdentifier != claims.subject) {
            throw BusinessException(ErrorCode.INVALID_APPLE_TOKEN)
        }
        reserveNonce(claims)

        val identity = externalIdentityRepository
            .findByProviderAndProviderSubject(AuthProvider.APPLE, claims.subject)
            ?: linkOrCreateIdentity(claims)
        storeAppleRefreshTokenIfAvailable(identity, command.authorizationCode)

        val member = identity.member
        val consentStatus = consentService.status(member.id)
        val memberProfile = MemberResult.me(member, imageUrlResolver.memberProfileImageUrl(member))
        val onboarding = onboarding(consentStatus.requiredConsentsAccepted, memberProfile.profileSetupRequired)

        return issueAndStoreTokens(member, memberProfile, onboarding)
    }

    private fun reserveNonce(claims: AppleOidcClaims) {
        val ttl = nonceReplayTtl(claims.expiresAt)
        if (!appleNonceReplayRepository.reserve(claims.nonce, ttl)) {
            throw BusinessException(ErrorCode.APPLE_NONCE_REPLAY)
        }
    }

    private fun nonceReplayTtl(expiresAt: Instant): Duration {
        val acceptedUntil = expiresAt.plus(allowedClockSkew)
        val untilExpiry = Duration.between(Instant.now(), acceptedUntil)
        if (untilExpiry <= Duration.ZERO) {
            throw BusinessException(ErrorCode.INVALID_APPLE_TOKEN)
        }
        return untilExpiry
    }

    private fun linkOrCreateIdentity(claims: AppleOidcClaims): ExternalIdentity {
        val email = claims.email?.takeIf { it.isNotBlank() && claims.emailVerified }
            ?: throw BusinessException(ErrorCode.APPLE_VERIFIED_EMAIL_REQUIRED)

        val member = memberRepository.findByEmail(email)
            ?: memberRepository.save(
                Member(
                    email = email,
                    passwordHash = null
                )
            )

        return externalIdentityRepository.save(
            ExternalIdentity(
                member = member,
                provider = AuthProvider.APPLE,
                providerSubject = claims.subject,
                emailAtLinkTime = email
            )
        )
    }

    private fun storeAppleRefreshTokenIfAvailable(
        identity: ExternalIdentity,
        authorizationCode: String?
    ) {
        val code = authorizationCode?.takeIf { it.isNotBlank() } ?: return
        val refreshToken = try {
            appleTokenPort.exchangeAuthorizationCode(code)?.refreshToken
        } catch (e: RuntimeException) {
            logger.warn(e) { "Failed to exchange Apple authorization code for memberId=${identity.member.id}" }
            null
        }?.takeIf { it.isNotBlank() } ?: return

        val encrypted = appleRefreshTokenCipher.encrypt(refreshToken)
        identity.storeAppleRefreshToken(
            ciphertext = encrypted.ciphertext,
            nonce = encrypted.nonce
        )
    }

    private fun onboarding(
        requiredConsentsAccepted: Boolean,
        profileSetupRequired: Boolean
    ): AuthResult.Onboarding {
        val requiredActions = buildList {
            if (!requiredConsentsAccepted) {
                add(AuthResult.OnboardingRequiredAction.ACCEPT_REQUIRED_POLICIES)
            }
            if (profileSetupRequired) {
                add(AuthResult.OnboardingRequiredAction.SETUP_PROFILE)
            }
        }
        val status = if (requiredActions.isEmpty()) {
            AuthResult.OnboardingStatus.COMPLETE
        } else {
            AuthResult.OnboardingStatus.REQUIRED
        }
        return AuthResult.Onboarding(status, requiredActions)
    }

    private fun issueAndStoreTokens(
        member: Member,
        memberProfile: MemberResult.Me,
        onboarding: AuthResult.Onboarding
    ): AuthResult.SocialLogin {
        val tokenPair = tokenProvider.generateToken(member.id, member.role)
        refreshTokenRepository.save(
            member.id,
            tokenPair.refreshToken,
            tokenProvider.getRefreshTokenValiditySeconds()
        )
        return AuthResult.SocialLogin(
            accessToken = tokenPair.accessToken,
            refreshToken = tokenPair.refreshToken,
            member = memberProfile,
            onboarding = onboarding
        )
    }

    private companion object {
        private val logger = KotlinLogging.logger {}
    }
}
