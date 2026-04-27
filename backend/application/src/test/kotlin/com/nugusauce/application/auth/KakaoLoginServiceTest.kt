package com.nugusauce.application.auth

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.redis.KakaoNonceReplayRepository
import com.nugusauce.application.redis.RefreshTokenRepository
import com.nugusauce.application.security.KakaoOidcClaims
import com.nugusauce.application.security.KakaoOidcTokenVerifier
import com.nugusauce.application.security.KakaoUserInfo
import com.nugusauce.application.security.KakaoUserInfoClient
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
            tokenProvider,
            refreshTokenRepository,
            600L,
            60L
        )
    }

    @Test
    fun `login reuses existing external identity`() {
        val member = Member(1L, "user@example.com", null, "ROLE_USER")
        val claims = claims()

        `when`(kakaoOidcTokenVerifier.verify("id-token", "nonce")).thenReturn(claims)
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.KAKAO, "kakao-sub"))
            .thenReturn(ExternalIdentity(1L, member, AuthProvider.KAKAO, "kakao-sub", "user@example.com"))
        `when`(tokenProvider.generateToken(1L, "ROLE_USER"))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        val result = service.login(AuthCommand.KakaoLogin("id-token", "nonce", "kakao-access-token"))

        assertEquals("access-token", result.accessToken)
        assertEquals("refresh-token", result.refreshToken)
        assertEquals(1L, result.member.id)
        assertEquals("사용자 1", result.member.displayName)
        assertTrue(result.member.profileSetupRequired)
        assertEquals("nonce", nonceRepository.lastNonce)
        verify(refreshTokenRepository).save(1L, "refresh-token", 120L)
    }

    @Test
    fun `login links existing member by verified email`() {
        val member = Member(2L, "user@example.com", "hashed-password", "ROLE_USER")
        val claims = claims()

        `when`(kakaoOidcTokenVerifier.verify("id-token", "nonce")).thenReturn(claims)
        `when`(externalIdentityRepository.findByProviderAndProviderSubject(AuthProvider.KAKAO, "kakao-sub"))
            .thenReturn(null)
        `when`(memberRepository.findByEmail("user@example.com")).thenReturn(member)
        `when`(externalIdentityRepository.save(Mockito.any(ExternalIdentity::class.java)))
            .thenAnswer { it.getArgument(0) }
        `when`(tokenProvider.generateToken(2L, "ROLE_USER"))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        service.login(AuthCommand.KakaoLogin("id-token", "nonce", "kakao-access-token"))

        val identityCaptor = ArgumentCaptor.forClass(ExternalIdentity::class.java)
        verify(externalIdentityRepository).save(identityCaptor.capture())
        assertEquals(member, identityCaptor.value.member)
        assertEquals(AuthProvider.KAKAO, identityCaptor.value.provider)
        assertEquals("kakao-sub", identityCaptor.value.providerSubject)
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
        `when`(tokenProvider.generateToken(3L, "ROLE_USER"))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        service.login(AuthCommand.KakaoLogin("id-token", "nonce", "kakao-access-token"))

        val memberCaptor = ArgumentCaptor.forClass(Member::class.java)
        verify(memberRepository).save(memberCaptor.capture())
        assertEquals("new@example.com", memberCaptor.value.email)
        assertNull(memberCaptor.value.passwordHash)
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
        `when`(tokenProvider.generateToken(1L, "ROLE_USER"))
            .thenReturn(AuthResult.TokenPair("access-token", "refresh-token"))
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        service.login(AuthCommand.KakaoLogin("id-token", "nonce", "kakao-access-token"))

        val ttl = nonceRepository.lastTtl ?: error("nonce TTL was not recorded")
        assertTrue(ttl > Duration.ZERO)
        assertTrue(ttl <= Duration.ofSeconds(60))
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
}
