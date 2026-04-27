package com.nugusauce.application.member

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import com.nugusauce.domain.member.Member
import com.nugusauce.domain.member.MemberRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import org.springframework.dao.DataIntegrityViolationException
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class MemberServiceTest {
    @Mock
    private lateinit var memberRepository: MemberRepository

    private lateinit var service: MemberService

    @BeforeEach
    fun setUp() {
        service = MemberService(memberRepository)
    }

    @Test
    fun `getMe returns setup required when nickname is missing`() {
        `when`(memberRepository.findById(1L))
            .thenReturn(Optional.of(Member(1L, "user@example.test", null)))

        val result = service.getMe(1L)

        assertEquals(1L, result.id)
        assertEquals("사용자 1", result.displayName)
        assertTrue(result.profileSetupRequired)
    }

    @Test
    fun `updateMe trims and stores valid nickname`() {
        val member = Member(1L, "user@example.test", null)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(memberRepository.existsByNicknameAndIdNot("소스장인", 1L)).thenReturn(false)

        val result = service.updateMe(MemberCommand.UpdateMe(1L, "  소스장인  "))

        assertEquals("소스장인", member.nickname)
        assertEquals("소스장인", result.displayName)
        assertFalse(result.profileSetupRequired)
    }

    @Test
    fun `updateMe rejects duplicate nickname`() {
        val member = Member(1L, "user@example.test", null)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(memberRepository.existsByNicknameAndIdNot("소스장인", 1L)).thenReturn(true)

        val exception = assertThrows(BusinessException::class.java) {
            service.updateMe(MemberCommand.UpdateMe(1L, "소스장인"))
        }

        assertEquals(ErrorCode.DUPLICATE_NICKNAME, exception.errorCode)
    }

    @Test
    fun `updateMe rejects invalid nickname`() {
        val member = Member(1L, "user@example.test", null)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        val exception = assertThrows(BusinessException::class.java) {
            service.updateMe(MemberCommand.UpdateMe(1L, "소스 장인"))
        }

        assertEquals(ErrorCode.INVALID_NICKNAME, exception.errorCode)
    }

    @Test
    fun `updateMe maps nickname unique constraint race to duplicate nickname`() {
        val member = Member(1L, "user@example.test", null)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(memberRepository.existsByNicknameAndIdNot("소스장인", 1L)).thenReturn(false)
        `when`(memberRepository.saveAndFlush(member))
            .thenThrow(DataIntegrityViolationException("Duplicate entry for key 'uk_member_nickname'"))

        val exception = assertThrows(BusinessException::class.java) {
            service.updateMe(MemberCommand.UpdateMe(1L, "소스장인"))
        }

        assertEquals(ErrorCode.DUPLICATE_NICKNAME, exception.errorCode)
    }
}
