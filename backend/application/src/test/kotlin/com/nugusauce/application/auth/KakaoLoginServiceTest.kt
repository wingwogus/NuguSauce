package com.nugusauce.application.auth

import com.nugusauce.application.consent.ConsentResult
import com.nugusauce.application.consent.ConsentService
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.media.ImageStoragePort
import com.nugusauce.application.media.MediaResult
import com.nugusauce.application.media.VerifiedUpload
import com.nugusauce.application.media.ImageUrlResolver
import com.nugusauce.application.redis.KakaoNonceReplayRepository
import com.nugusauce.application.redis.RefreshTokenRepository
import com.nugusauce.application.security.KakaoOidcClaims
import com.nugusauce.application.security.KakaoOidcTokenVerifier
import com.nugusauce.application.security.KakaoUserInfo
import com.nugusauce.application.security.KakaoUserInfoClient
import com.nugusauce.application.security.TokenProvider
import com.nugusauce.domain.media.MediaAsset
import com.nugusauce.domain.media.MediaProvider
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
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import java.time.Duration
import java.time.Instant

@ExtendWith(MockitoExtension::class)
class KakaoLoginServiceTest {

    @Mock
    private lateinit var kakaoOidcTokenVerifier: KakaoOidcTokenVerifier

    @Mock
    private lateinit var kakaoUserInfoClient: KakaoUserInfoClient

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

    private lateinit var nonceRepository: RecordingNonceRepository
    private lateinit var service: KakaoLoginService

    @BeforeEach
    fun setUp() {
        nonceRepository = RecordingNonceRepository()
        service = KakaoLoginService(
            kakaoOidcTokenVerifier,
            kakaoUserInfoClient,
            nonceRepository,
            externalIdentityRepository,
            memberRepository,
            consentService,
            tokenProvider,
            refreshTokenRepository,
            ImageUrlResolver(TestImageStoragePort),
            600L,
            60L
        )
    }

    @Test
    fun `login reuses existing external identity`() {
        val member = Member(1L, "user@example.com", null, "ROLE_USER").apply {
            profileImageAsset = MediaAsset(
                id = 50L,
                owner = this,
                provider = MediaProvider.CLOUDINARY,
                providerKey = "nugusauce/images/1/profile",
                contentType = "image/jpeg",
                byteSize = 2000L
            )
        }
        val claims = claims()

        `when`(kakaoOidcTokenVerifier.verify("id-token", "nonce")).thenReturn(claims)
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.KAKAO, "kakao-sub"))
            .thenReturn(ExternalIdentity(1L, member, AuthProvider.KAKAO, "kakao-sub", "user@example.com"))
        `when`(consentService.status(1L)).thenReturn(consentStatus(accepted = true))
        `when`(tokenProvider.generateToken(1L, "ROLE_USER"))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        val result = service.login(AuthCommand.KakaoLogin("id-token", "nonce", "kakao-access-token"))

        assertEquals("access-token", result.accessToken)
        assertEquals("refresh-token", result.refreshToken)
        assertEquals(1L, result.member.id)
        assertEquals("사용자 1", result.member.displayName)
        assertEquals("https://cdn.example.test/nugusauce/images/1/profile", result.member.profileImageUrl)
        assertTrue(result.member.profileSetupRequired)
        assertEquals(AuthResult.LoginNextStep.PROFILE_REQUIRED, result.nextStep)
        assertEquals("nonce", nonceRepository.lastNonce)
        verify(refreshTokenRepository).save(1L, "refresh-token", 120L)
    }

    @Test
    fun `login links existing member by verified email`() {
        val member = Member(2L, "user@example.com", "hashed-password", "ROLE_USER").apply {
            nickname = "소스장인"
        }
        val claims = claims()

        `when`(kakaoOidcTokenVerifier.verify("id-token", "nonce")).thenReturn(claims)
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.KAKAO, "kakao-sub"))
            .thenReturn(null)
        `when`(memberRepository.findByEmail("user@example.com")).thenReturn(member)
        `when`(externalIdentityRepository.save(Mockito.any(ExternalIdentity::class.java)))
            .thenAnswer { it.getArgument(0) }
        `when`(consentService.status(2L)).thenReturn(consentStatus(accepted = true))
        `when`(tokenProvider.generateToken(2L, "ROLE_USER"))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        val result = service.login(AuthCommand.KakaoLogin("id-token", "nonce", "kakao-access-token"))

        val identityCaptor = ArgumentCaptor.forClass(ExternalIdentity::class.java)
        verify(externalIdentityRepository).save(identityCaptor.capture())
        assertEquals(member, identityCaptor.value.member)
        assertEquals(AuthProvider.KAKAO, identityCaptor.value.provider)
        assertEquals("kakao-sub", identityCaptor.value.providerSubject)
        assertEquals(AuthResult.LoginNextStep.DONE, result.nextStep)
    }

    @Test
    fun `login creates new member with null password hash`() {
        val savedMember = Member(3L, "new@example.com", null, "ROLE_USER")

        `when`(kakaoOidcTokenVerifier.verify("id-token", "nonce")).thenReturn(claims(email = "new@example.com"))
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.KAKAO, "kakao-sub"))
            .thenReturn(null)
        `when`(memberRepository.findByEmail("new@example.com")).thenReturn(null)
        `when`(memberRepository.save(Mockito.any(Member::class.java))).thenReturn(savedMember)
        `when`(externalIdentityRepository.save(Mockito.any(ExternalIdentity::class.java)))
            .thenAnswer { it.getArgument(0) }
        `when`(consentService.status(3L)).thenReturn(consentStatus(accepted = false))
        `when`(tokenProvider.generateToken(3L, "ROLE_USER"))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        val result = service.login(AuthCommand.KakaoLogin("id-token", "nonce", "kakao-access-token"))

        val memberCaptor = ArgumentCaptor.forClass(Member::class.java)
        verify(memberRepository).save(memberCaptor.capture())
        assertEquals("new@example.com", memberCaptor.value.email)
        assertNull(memberCaptor.value.passwordHash)
        assertEquals(AuthResult.LoginNextStep.CONSENT_REQUIRED, result.nextStep)
    }

    @Test
    fun `login rejects missing verified email`() {
        `when`(kakaoOidcTokenVerifier.verify("id-token", "nonce"))
            .thenReturn(claims(email = null, emailVerified = false))
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.KAKAO, "kakao-sub"))
            .thenReturn(null)

        val exception = assertThrows(BusinessException::class.java) {
            service.login(AuthCommand.KakaoLogin("id-token", "nonce", null))
        }

        assertEquals(ErrorCode.KAKAO_VERIFIED_EMAIL_REQUIRED, exception.errorCode)
    }

    @Test
    fun `login verifies email through kakao userinfo when id token has no email verification`() {
        val savedMember = Member(4L, "userinfo@example.com", null, "ROLE_USER")

        `when`(kakaoOidcTokenVerifier.verify("id-token", "nonce"))
            .thenReturn(claims(email = "userinfo@example.com", emailVerified = false))
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.KAKAO, "kakao-sub"))
            .thenReturn(null)
        `when`(kakaoUserInfoClient.fetch("kakao-access-token"))
            .thenReturn(KakaoUserInfo("kakao-sub", "userinfo@example.com", true))
        `when`(memberRepository.findByEmail("userinfo@example.com")).thenReturn(null)
        `when`(memberRepository.save(Mockito.any(Member::class.java))).thenReturn(savedMember)
        `when`(externalIdentityRepository.save(Mockito.any(ExternalIdentity::class.java)))
            .thenAnswer { it.getArgument(0) }
        `when`(consentService.status(4L)).thenReturn(consentStatus(accepted = true))
        `when`(tokenProvider.generateToken(4L, "ROLE_USER"))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        service.login(AuthCommand.KakaoLogin("id-token", "nonce", "kakao-access-token"))

        val memberCaptor = ArgumentCaptor.forClass(Member::class.java)
        verify(memberRepository).save(memberCaptor.capture())
        assertEquals("userinfo@example.com", memberCaptor.value.email)
    }

    @Test
    fun `login rejects kakao userinfo subject mismatch`() {
        `when`(kakaoOidcTokenVerifier.verify("id-token", "nonce"))
            .thenReturn(claims(email = null, emailVerified = false))
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.KAKAO, "kakao-sub"))
            .thenReturn(null)
        `when`(kakaoUserInfoClient.fetch("kakao-access-token"))
            .thenReturn(KakaoUserInfo("other-sub", "user@example.com", true))

        val exception = assertThrows(BusinessException::class.java) {
            service.login(AuthCommand.KakaoLogin("id-token", "nonce", "kakao-access-token"))
        }

        assertEquals(ErrorCode.INVALID_KAKAO_TOKEN, exception.errorCode)
    }

    @Test
    fun `login rejects replayed nonce`() {
        nonceRepository.reserveResult = false
        `when`(kakaoOidcTokenVerifier.verify("id-token", "nonce")).thenReturn(claims())

        val exception = assertThrows(BusinessException::class.java) {
            service.login(AuthCommand.KakaoLogin("id-token", "nonce", "kakao-access-token"))
        }

        assertEquals(ErrorCode.KAKAO_NONCE_REPLAY, exception.errorCode)
    }

    @Test
    fun `login reserves nonce for token accepted within clock skew`() {
        val member = Member(1L, "user@example.com", null, "ROLE_USER")

        `when`(kakaoOidcTokenVerifier.verify("id-token", "nonce")).thenReturn(
            claims(expiresAt = Instant.now().minusSeconds(10))
        )
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.KAKAO, "kakao-sub"))
            .thenReturn(ExternalIdentity(1L, member, AuthProvider.KAKAO, "kakao-sub", "user@example.com"))
        `when`(consentService.status(1L)).thenReturn(consentStatus(accepted = true))
        `when`(tokenProvider.generateToken(1L, "ROLE_USER"))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        service.login(AuthCommand.KakaoLogin("id-token", "nonce", "kakao-access-token"))

        val ttl = nonceRepository.lastTtl ?: error("nonce TTL was not recorded")
        assertTrue(ttl > Duration.ZERO)
        assertTrue(ttl <= Duration.ofSeconds(60))
    }

    @Test
    fun `login does not issue tokens when consent status cannot be computed`() {
        val member = Member(1L, "user@example.com", null, "ROLE_USER")

        `when`(kakaoOidcTokenVerifier.verify("id-token", "nonce")).thenReturn(claims())
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.KAKAO, "kakao-sub"))
            .thenReturn(ExternalIdentity(1L, member, AuthProvider.KAKAO, "kakao-sub", "user@example.com"))
        `when`(consentService.status(1L))
            .thenThrow(object : BusinessException(ErrorCode.CONSENT_REQUIRED) {})

        val exception = assertThrows(BusinessException::class.java) {
            service.login(AuthCommand.KakaoLogin("id-token", "nonce", "kakao-access-token"))
        }

        assertEquals(ErrorCode.CONSENT_REQUIRED, exception.errorCode)
        verify(tokenProvider, never()).generateToken(Mockito.anyLong(), Mockito.anyString())
        verify(refreshTokenRepository, never()).save(Mockito.anyLong(), Mockito.anyString(), Mockito.anyLong())
    }

    private fun claims(
        email: String? = "user@example.com",
        emailVerified: Boolean = true,
        expiresAt: Instant = Instant.now().plusSeconds(300)
    ): KakaoOidcClaims {
        return KakaoOidcClaims(
            subject = "kakao-sub",
            email = email,
            emailVerified = emailVerified,
            nonce = "nonce",
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

    private class RecordingNonceRepository : KakaoNonceReplayRepository {
        var reserveResult = true
        var lastNonce: String? = null
        var lastTtl: Duration? = null

        override fun reserve(nonce: String, ttl: Duration): Boolean {
            lastNonce = nonce
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
