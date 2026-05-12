package com.nugusauce.application.auth

import com.nugusauce.application.consent.ConsentResult
import com.nugusauce.application.consent.ConsentService
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.application.media.MediaResult
import com.nugusauce.application.media.VerifiedUpload
import com.nugusauce.application.redis.AppleNonceReplayRepository
import com.nugusauce.application.redis.RefreshTokenRepository
import com.nugusauce.application.security.AppleOidcClaims
import com.nugusauce.application.security.AppleOidcTokenVerifier
import com.nugusauce.application.security.TokenProvider
import com.nugusauce.domain.member.AuthProvider
import com.nugusauce.domain.member.ExternalIdentity
import com.nugusauce.domain.member.ExternalIdentityRepository
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.ArgumentCaptor
import org.mockito.Mock
import org.mockito.Mockito
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.verifyNoInteractions
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import java.time.Duration
import java.time.Instant

@ExtendWith(MockitoExtension::class)
class AppleLoginServiceTest {

    @Mock
    private lateinit var appleOidcTokenVerifier: AppleOidcTokenVerifier

    @Mock
    private lateinit var externalIdentityRepository: ExternalIdentityRepository

    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var consentService: ConsentService

    @Mock
    private lateinit var tokenProvider: TokenProvider

    @Mock
    private lateinit var refreshTokenRepository: RefreshTokenRepository

    private lateinit var nonceRepository: RecordingAppleNonceRepository
    private lateinit var service: AppleLoginService

    @BeforeEach
    fun setUp() {
        nonceRepository = RecordingAppleNonceRepository()
        service = AppleLoginService(
            appleOidcTokenVerifier,
            nonceRepository,
            externalIdentityRepository,
            memberRepository,
            consentService,
            tokenProvider,
            refreshTokenRepository,
            ImageUrlResolver(TestImageStoragePort),
            60L
        )
    }

    @Test
    fun `login reuses existing apple external identity`() {
        val member = Member(1L, "relay@privaterelay.appleid.com", null, "ROLE_USER")

        `when`(appleOidcTokenVerifier.verify("identity-token", "raw-nonce")).thenReturn(claims())
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.APPLE, "apple-sub"))
            .thenReturn(ExternalIdentity(1L, member, AuthProvider.APPLE, "apple-sub", "relay@privaterelay.appleid.com"))
        `when`(consentService.status(1L)).thenReturn(consentStatus(accepted = true))
        `when`(tokenProvider.generateToken(1L, "ROLE_USER"))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        val result = service.login(AuthCommand.AppleLogin("identity-token", "raw-nonce", "authorization-code", "apple-sub"))

        assertEquals("access-token", result.accessToken)
        assertEquals("refresh-token", result.refreshToken)
        assertEquals(1L, result.member.id)
        assertEquals("nonce-hash", nonceRepository.lastNonceHash)
        verify(refreshTokenRepository).save(1L, "refresh-token", 120L)
    }

    @Test
    fun `login links existing member by verified apple email`() {
        val member = Member(2L, "relay@privaterelay.appleid.com", "hashed-password", "ROLE_USER").apply {
            nickname = "소스장인"
        }

        `when`(appleOidcTokenVerifier.verify("identity-token", "raw-nonce")).thenReturn(claims())
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.APPLE, "apple-sub"))
            .thenReturn(null)
        `when`(memberRepository.findByEmail("relay@privaterelay.appleid.com")).thenReturn(member)
        `when`(externalIdentityRepository.save(Mockito.any(ExternalIdentity::class.java)))
            .thenAnswer { it.getArgument(0) }
        `when`(consentService.status(2L)).thenReturn(consentStatus(accepted = true))
        `when`(tokenProvider.generateToken(2L, "ROLE_USER"))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        val result = service.login(AuthCommand.AppleLogin("identity-token", "raw-nonce", null, null))

        val identityCaptor = ArgumentCaptor.forClass(ExternalIdentity::class.java)
        verify(externalIdentityRepository).save(identityCaptor.capture())
        assertEquals(member, identityCaptor.value.member)
        assertEquals(AuthProvider.APPLE, identityCaptor.value.provider)
        assertEquals("apple-sub", identityCaptor.value.providerSubject)
        assertEquals(AuthResult.OnboardingStatus.COMPLETE, result.onboarding.status)
    }

    @Test
    fun `login creates new member with verified apple email and both onboarding actions`() {
        val savedMember = Member(3L, "relay@privaterelay.appleid.com", null, "ROLE_USER")

        `when`(appleOidcTokenVerifier.verify("identity-token", "raw-nonce")).thenReturn(claims())
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.APPLE, "apple-sub"))
            .thenReturn(null)
        `when`(memberRepository.findByEmail("relay@privaterelay.appleid.com")).thenReturn(null)
        `when`(memberRepository.save(Mockito.any(Member::class.java))).thenReturn(savedMember)
        `when`(externalIdentityRepository.save(Mockito.any(ExternalIdentity::class.java)))
            .thenAnswer { it.getArgument(0) }
        `when`(consentService.status(3L)).thenReturn(consentStatus(accepted = false))
        `when`(tokenProvider.generateToken(3L, "ROLE_USER"))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        val result = service.login(AuthCommand.AppleLogin("identity-token", "raw-nonce", null, null))

        val memberCaptor = ArgumentCaptor.forClass(Member::class.java)
        verify(memberRepository).save(memberCaptor.capture())
        assertEquals("relay@privaterelay.appleid.com", memberCaptor.value.email)
        assertNull(memberCaptor.value.passwordHash)
        assertEquals(
            listOf(
                AuthResult.OnboardingRequiredAction.ACCEPT_REQUIRED_POLICIES,
                AuthResult.OnboardingRequiredAction.SETUP_PROFILE
            ),
            result.onboarding.requiredActions
        )
    }

    @Test
    fun `login rejects missing verified email for first apple identity`() {
        `when`(appleOidcTokenVerifier.verify("identity-token", "raw-nonce"))
            .thenReturn(claims(email = null, emailVerified = false))
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.APPLE, "apple-sub"))
            .thenReturn(null)

        val exception = assertThrows(BusinessException::class.java) {
            service.login(AuthCommand.AppleLogin("identity-token", "raw-nonce", null, null))
        }

        assertEquals(ErrorCode.APPLE_VERIFIED_EMAIL_REQUIRED, exception.errorCode)
    }

    @Test
    fun `login rejects replayed apple nonce before member lookup`() {
        nonceRepository.reserveResult = false
        `when`(appleOidcTokenVerifier.verify("identity-token", "raw-nonce")).thenReturn(claims())

        val exception = assertThrows(BusinessException::class.java) {
            service.login(AuthCommand.AppleLogin("identity-token", "raw-nonce", null, null))
        }

        assertEquals(ErrorCode.APPLE_NONCE_REPLAY, exception.errorCode)
        verifyNoInteractions(externalIdentityRepository)
    }

    @Test
    fun `login reserves apple nonce for the full accepted token window`() {
        val member = Member(1L, "relay@privaterelay.appleid.com", null, "ROLE_USER")

        `when`(
            appleOidcTokenVerifier.verify("identity-token", "raw-nonce")
        ).thenReturn(claims(expiresAt = Instant.now().plusSeconds(600)))
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.APPLE, "apple-sub"))
            .thenReturn(ExternalIdentity(1L, member, AuthProvider.APPLE, "apple-sub", "relay@privaterelay.appleid.com"))
        `when`(consentService.status(1L)).thenReturn(consentStatus(accepted = true))
        `when`(tokenProvider.generateToken(1L, "ROLE_USER"))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        service.login(AuthCommand.AppleLogin("identity-token", "raw-nonce", null, null))

        val ttl = nonceRepository.lastTtl ?: error("Apple nonce replay TTL was not recorded")
        assertTrue(ttl > Duration.ofSeconds(600))
        assertTrue(ttl <= Duration.ofSeconds(660))
    }

    @Test
    fun `login rejects user identifier mismatch`() {
        `when`(appleOidcTokenVerifier.verify("identity-token", "raw-nonce")).thenReturn(claims())

        val exception = assertThrows(BusinessException::class.java) {
            service.login(AuthCommand.AppleLogin("identity-token", "raw-nonce", null, "other-sub"))
        }

        assertEquals(ErrorCode.INVALID_APPLE_TOKEN, exception.errorCode)
    }

    @Test
    fun `login does not issue tokens when consent status cannot be computed`() {
        val member = Member(1L, "relay@privaterelay.appleid.com", null, "ROLE_USER")

        `when`(appleOidcTokenVerifier.verify("identity-token", "raw-nonce")).thenReturn(claims())
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.APPLE, "apple-sub"))
            .thenReturn(ExternalIdentity(1L, member, AuthProvider.APPLE, "apple-sub", "relay@privaterelay.appleid.com"))
        `when`(consentService.status(1L))
            .thenThrow(object : BusinessException(ErrorCode.CONSENT_REQUIRED) {})

        val exception = assertThrows(BusinessException::class.java) {
            service.login(AuthCommand.AppleLogin("identity-token", "raw-nonce", null, null))
        }

        assertEquals(ErrorCode.CONSENT_REQUIRED, exception.errorCode)
        verify(tokenProvider, never()).generateToken(Mockito.anyLong(), Mockito.anyString())
        verify(refreshTokenRepository, never()).save(Mockito.anyLong(), Mockito.anyString(), Mockito.anyLong())
    }

    private fun claims(
        email: String? = "relay@privaterelay.appleid.com",
        emailVerified: Boolean = true,
        expiresAt: Instant = Instant.now().plusSeconds(300)
    ): AppleOidcClaims {
        return AppleOidcClaims(
            subject = "apple-sub",
            email = email,
            emailVerified = emailVerified,
            nonce = "nonce-hash",
            expiresAt = expiresAt
        )
    }

    private fun consentStatus(accepted: Boolean): ConsentResult.Status {
        return ConsentResult.Status(
            policies = emptyList(),
            missingPolicies = if (accepted) emptyList() else listOf(missingPolicy()),
            requiredConsentsAccepted = accepted
        )
    }

    private fun missingPolicy(): ConsentResult.PolicyStatus {
        return ConsentResult.PolicyStatus(
            policyType = "terms_of_service",
            version = "2026-05-01",
            title = "서비스 이용약관",
            url = "nugusauce://legal/terms",
            required = true,
            accepted = false,
            activeFrom = Instant.parse("2026-05-01T00:00:00Z")
        )
    }

    private class RecordingAppleNonceRepository : AppleNonceReplayRepository {
        var reserveResult = true
        var lastNonceHash: String? = null
        var lastTtl: Duration? = null

        override fun reserve(nonceHash: String, ttl: Duration): Boolean {
            lastNonceHash = nonceHash
            lastTtl = ttl
            return reserveResult
        }
    }

    private object TestImageStoragePort : ImageStoragePort {
        override fun createUploadTarget(
            providerKey: String,
            contentType: String,
            expiresAt: Instant
        ): MediaResult.UploadTarget {
            throw UnsupportedOperationException()
        }

        override fun verifyUpload(providerKey: String): VerifiedUpload {
            throw UnsupportedOperationException()
        }

        override fun displayUrl(providerKey: String): String {
            return "https://cdn.example.test/$providerKey"
        }

        override fun delete(providerKey: String) {
            throw UnsupportedOperationException()
        }
    }
}
