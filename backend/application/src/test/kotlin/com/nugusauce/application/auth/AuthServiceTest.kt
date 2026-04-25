package com.nugusauce.application.auth

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.redis.EmailVerificationRepository
import com.nugusauce.application.redis.RefreshTokenRepository
import com.nugusauce.application.security.TokenProvider
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.Mockito.verify
import org.mockito.junit.jupiter.MockitoExtension
import org.springframework.security.crypto.password.PasswordEncoder

@ExtendWith(MockitoExtension::class)
class AuthServiceTest {

    @Mock
    private lateinit var tokenProvider: TokenProvider

    @Mock
    private lateinit var emailSender: EmailSender

    @Mock
    private lateinit var verificationCodeGenerator: VerificationCodeGenerator

    @Mock
    private lateinit var emailVerificationRepository: EmailVerificationRepository

    @Mock
    private lateinit var refreshTokenRepository: RefreshTokenRepository

    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var passwordEncoder: PasswordEncoder

    private lateinit var authService: AuthService

    private val codeTtlMillis = 180_000L
    private val verifiedTtlMillis = 300_000L

    @BeforeEach
    fun setUp() {
        authService = AuthService(
            tokenProvider,
            emailSender,
            verificationCodeGenerator,
            emailVerificationRepository,
            refreshTokenRepository,
            memberRepository,
            passwordEncoder,
            codeTtlMillis,
            verifiedTtlMillis
        )
    }

    @Test
    fun `sendVerificationCode stores generated code and sends email`() {
        `when`(memberRepository.existsByEmail("user@example.com")).thenReturn(false)
        `when`(verificationCodeGenerator.generate()).thenReturn("123456")

        authService.sendVerificationCode(AuthCommand.SendVerificationCode("user@example.com"))

        verify(emailSender).sendVerificationCode("user@example.com", "123456")
        verify(emailVerificationRepository).saveCode("user@example.com", "123456", java.time.Duration.ofMillis(codeTtlMillis))
    }

    @Test
    fun `signUp rejects unverified email`() {
        `when`(emailVerificationRepository.isVerified("user@example.com")).thenReturn(false)

        val exception = assertThrows(BusinessException::class.java) {
            authService.signUp(AuthCommand.SignUp("user@example.com", "password123"))
        }

        assertEquals(ErrorCode.EMAIL_NOT_VERIFIED, exception.errorCode)
    }

    @Test
    fun `login stores refresh token and returns tokens`() {
        val member = Member(
            id = 1L,
            email = "user@example.com",
            passwordHash = "hashed",
            role = "ROLE_USER"
        )
        val tokenPair = AuthResult.TokenPair("access-token", "refresh-token")

        `when`(memberRepository.findByEmail("user@example.com")).thenReturn(member)
        `when`(passwordEncoder.matches("password123", "hashed")).thenReturn(true)
        `when`(tokenProvider.generateToken(1L, "ROLE_USER")).thenReturn(tokenPair)
        `when`(tokenProvider.getRefreshTokenValiditySeconds()).thenReturn(120L)

        val result = authService.login(AuthCommand.Login("user@example.com", "password123"))

        assertEquals(tokenPair, result)
        verify(refreshTokenRepository).save(1L, "refresh-token", 120L)
    }

    @Test
    fun `login rejects social-only member without password hash`() {
        val member = Member(
            id = 1L,
            email = "user@example.com",
            passwordHash = null,
            role = "ROLE_USER"
        )

        `when`(memberRepository.findByEmail("user@example.com")).thenReturn(member)

        val exception = assertThrows(BusinessException::class.java) {
            authService.login(AuthCommand.Login("user@example.com", "password123"))
        }

        assertEquals(ErrorCode.SOCIAL_ONLY_MEMBER_LOCAL_LOGIN_FORBIDDEN, exception.errorCode)
    }

    @Test
    fun `reissue rejects refresh token mismatch`() {
        `when`(tokenProvider.validateToken("refresh-token")).thenReturn(true)
        `when`(tokenProvider.isRefreshToken("refresh-token")).thenReturn(true)
        `when`(tokenProvider.getUserId("refresh-token")).thenReturn(1L)
        `when`(refreshTokenRepository.get(1L)).thenReturn("different-refresh-token")

        val exception = assertThrows(BusinessException::class.java) {
            authService.reissue(AuthCommand.Reissue("refresh-token"))
        }

        assertEquals(ErrorCode.UNAUTHORIZED, exception.errorCode)
    }

    @Test
    fun `logout deletes stored refresh token`() {
        `when`(refreshTokenRepository.get(1L)).thenReturn("refresh-token")

        authService.logout("1")

        verify(refreshTokenRepository).delete(1L)
    }
}
