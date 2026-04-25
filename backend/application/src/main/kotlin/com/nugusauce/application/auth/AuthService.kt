package com.nugusauce.application.auth

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.application.redis.EmailVerificationRepository
import com.nugusauce.application.redis.RefreshTokenRepository
import com.nugusauce.application.security.TokenProvider
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Duration

@Service
@Transactional
class AuthService(
    private val tokenProvider: TokenProvider,
    private val emailSender: EmailSender,
    private val verificationCodeGenerator: VerificationCodeGenerator,
    private val emailVerificationRepository: EmailVerificationRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val memberRepository: MemberRepository,
    private val passwordEncoder: PasswordEncoder,
    @Value("\${spring.mail.auth-code-expiration-millis}")
    private val codeTtlMillis: Long,
    @Value("\${spring.mail.verified-state-expiration-millis:\${spring.mail.auth-code-expiration-millis}}")
    private val verifiedTtlMillis: Long
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    fun sendVerificationCode(command: AuthCommand.SendVerificationCode) {
        if (memberRepository.existsByEmail(command.email)) {
            throw BusinessException(ErrorCode.DUPLICATE_EMAIL)
        }

        val code = verificationCodeGenerator.generate()
        emailSender.sendVerificationCode(command.email, code)
        emailVerificationRepository.saveCode(
            command.email,
            code,
            Duration.ofMillis(codeTtlMillis)
        )
        logger.info("Verification code sent. emailHash={}", command.email.hashCode())
    }

    fun verifyEmailCode(command: AuthCommand.VerifyEmailCode) {
        if (memberRepository.existsByEmail(command.email)) {
            throw BusinessException(ErrorCode.DUPLICATE_EMAIL)
        }

        val storedCode = emailVerificationRepository.getCode(command.email)
            ?: throw BusinessException(ErrorCode.AUTH_CODE_NOT_FOUND)

        if (storedCode != command.code) {
            throw BusinessException(ErrorCode.AUTH_CODE_MISMATCH)
        }

        emailVerificationRepository.markVerified(
            command.email,
            Duration.ofMillis(verifiedTtlMillis)
        )
        emailVerificationRepository.deleteCode(command.email)
        logger.info("Email verified. emailHash={}", command.email.hashCode())
    }

    fun signUp(command: AuthCommand.SignUp) {
        if (!emailVerificationRepository.isVerified(command.email)) {
            throw BusinessException(ErrorCode.EMAIL_NOT_VERIFIED)
        }

        if (memberRepository.existsByEmail(command.email)) {
            throw BusinessException(ErrorCode.DUPLICATE_EMAIL)
        }

        memberRepository.save(
            Member(
                email = command.email,
                passwordHash = passwordEncoder.encode(command.password)
            )
        )
        emailVerificationRepository.deleteCode(command.email)
        emailVerificationRepository.deleteVerified(command.email)
        logger.info("Member signed up. emailHash={}", command.email.hashCode())
    }

    fun login(command: AuthCommand.Login): AuthResult.TokenPair {
        val member = memberRepository.findByEmail(command.email)
            ?: throw BusinessException(ErrorCode.UNAUTHORIZED)

        val passwordHash = member.passwordHash
            ?: throw BusinessException(ErrorCode.SOCIAL_ONLY_MEMBER_LOCAL_LOGIN_FORBIDDEN)

        if (!passwordEncoder.matches(command.password, passwordHash)) {
            throw BusinessException(ErrorCode.UNAUTHORIZED)
        }

        return issueAndStoreTokens(member)
    }

    fun reissue(command: AuthCommand.Reissue): AuthResult.TokenPair {
        if (!tokenProvider.validateToken(command.refreshToken) || !tokenProvider.isRefreshToken(command.refreshToken)) {
            throw BusinessException(ErrorCode.UNAUTHORIZED)
        }

        val userId = tokenProvider.getUserId(command.refreshToken)
        val storedRefreshToken = refreshTokenRepository.get(userId)
            ?: throw BusinessException(ErrorCode.UNAUTHORIZED)

        if (storedRefreshToken != command.refreshToken) {
            throw BusinessException(ErrorCode.UNAUTHORIZED)
        }

        val member = memberRepository.findById(userId).orElseThrow {
            BusinessException(ErrorCode.USER_NOT_FOUND)
        }

        return issueAndStoreTokens(member)
    }

    fun logout(userId: String) {
        val parsedUserId = userId.toLongOrNull()
            ?: throw BusinessException(ErrorCode.UNAUTHORIZED)

        if (refreshTokenRepository.get(parsedUserId) == null) {
            throw BusinessException(ErrorCode.ALREADY_LOGGED_OUT)
        }

        refreshTokenRepository.delete(parsedUserId)
        logger.info("Member logged out. userHash={}", userId.hashCode())
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
