package com.nugusauce.application.common.cursor

import com.fasterxml.jackson.databind.ObjectMapper
import com.nugusauce.application.exception.ErrorCode
import com.nugusauce.application.exception.business.BusinessException
import java.nio.charset.StandardCharsets
import java.util.Base64

class CursorCodec(
    private val objectMapper: ObjectMapper = ObjectMapper()
) {
    fun decode(cursor: String?, expectedShape: CursorShape): DecodedCursor? {
        val encoded = cursor?.trim()?.takeIf { it.isNotBlank() } ?: return null
        val payload = try {
            val json = String(Base64.getUrlDecoder().decode(encoded), StandardCharsets.UTF_8)
            objectMapper.readValue(json, Map::class.java)
        } catch (e: Exception) {
            throw invalidCursor("malformed cursor")
        }

        val version = payload["v"].asInt("v")
        if (version != CURSOR_VERSION) {
            throw invalidCursor("unsupported cursor version")
        }

        val actualShape = CursorShape(payload["shape"].asStringMap("shape"))
        if (actualShape != expectedShape) {
            throw invalidCursor("cursor does not match request")
        }

        val offset = payload["offset"].asLong("offset")
        if (offset < 0) {
            throw invalidCursor("invalid offset")
        }

        return DecodedCursor(offset = offset)
    }

    fun encode(shape: CursorShape, offset: Long): String {
        require(offset >= 0) { "cursor offset must not be negative" }

        val payload = linkedMapOf<String, Any?>(
            "v" to CURSOR_VERSION,
            "shape" to shape.values.toSortedMap(),
            "offset" to offset
        )
        val json = objectMapper.writeValueAsString(payload)
        return Base64.getUrlEncoder()
            .withoutPadding()
            .encodeToString(json.toByteArray(StandardCharsets.UTF_8))
    }

    private fun Any?.asInt(field: String): Int {
        return (this as? Number)?.toInt() ?: throw invalidCursor("invalid $field")
    }

    private fun Any?.asLong(field: String): Long {
        return (this as? Number)?.toLong() ?: throw invalidCursor("invalid $field")
    }

    private fun Any?.asStringMap(field: String): Map<String, String?> {
        val rawMap = this as? Map<*, *> ?: throw invalidCursor("invalid $field")
        return rawMap.mapKeys { (key, _) ->
            key as? String ?: throw invalidCursor("invalid $field")
        }.mapValues { (_, value) ->
            when (value) {
                null -> null
                is String -> value
                else -> throw invalidCursor("invalid $field")
            }
        }
    }

    private fun invalidCursor(reason: String): BusinessException {
        return BusinessException(
            ErrorCode.INVALID_INPUT,
            detail = mapOf("field" to "cursor", "reason" to reason)
        )
    }

    private companion object {
        const val CURSOR_VERSION = 1
    }
}

data class CursorShape(
    val values: Map<String, String?>
)

data class DecodedCursor(
    val offset: Long
)
