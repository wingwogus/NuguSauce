package com.nugusauce.application.common.cursor

import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test

class CursorCodecTest {
    private val codec = CursorCodec()

    @Test
    fun `blank cursor decodes to null`() {
        assertNull(codec.decode(" ", shape()))
    }

    @Test
    fun `encodes and decodes offset with matching shape`() {
        val cursor = codec.encode(shape(), offset = 40)

        val decoded = codec.decode(cursor, shape())

        assertEquals(40, decoded?.offset)
    }

    @Test
    fun `rejects cursor when shape changes`() {
        val cursor = codec.encode(shape("sort" to "popular"), offset = 20)

        val exception = assertThrows(BusinessException::class.java) {
            codec.decode(cursor, shape("sort" to "recent"))
        }

        assertEquals(ErrorCode.INVALID_INPUT, exception.errorCode)
    }

    private fun shape(vararg overrides: Pair<String, String?>): CursorShape {
        return CursorShape(
            mapOf(
                "q" to null,
                "tagIds" to "1,2",
                "ingredientIds" to "",
                "sort" to "popular",
                "limit" to "20"
            ) + overrides
        )
    }
}
