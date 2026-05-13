package com.nugusauce.application.security

import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

@Component
class AppleRefreshTokenCipher(
    @Value("\${auth.apple.refresh-token-encryption-key:\${jwt.secret}}")
    encryptionKey: String
) {
    private val secureRandom = SecureRandom()
    private val key = SecretKeySpec(deriveKey(encryptionKey), "AES")

    fun encrypt(plainText: String): EncryptedAppleRefreshToken {
        require(plainText.isNotBlank()) {
            "apple refresh token must not be blank"
        }
        val nonce = ByteArray(NONCE_BYTES)
        secureRandom.nextBytes(nonce)
        val cipher = Cipher.getInstance(AES_GCM_TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(TAG_BITS, nonce))
        val ciphertext = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))
        return EncryptedAppleRefreshToken(
            ciphertext = Base64.getEncoder().encodeToString(ciphertext),
            nonce = Base64.getEncoder().encodeToString(nonce)
        )
    }

    fun decrypt(ciphertext: String, nonce: String): String {
        val cipher = Cipher.getInstance(AES_GCM_TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            key,
            GCMParameterSpec(TAG_BITS, Base64.getDecoder().decode(nonce))
        )
        return String(
            cipher.doFinal(Base64.getDecoder().decode(ciphertext)),
            Charsets.UTF_8
        )
    }

    private fun deriveKey(encryptionKey: String): ByteArray {
        val decoded = try {
            Base64.getDecoder().decode(encryptionKey)
        } catch (e: IllegalArgumentException) {
            encryptionKey.toByteArray(Charsets.UTF_8)
        }
        require(decoded.isNotEmpty()) {
            "auth.apple.refresh-token-encryption-key must not be blank"
        }
        return MessageDigest.getInstance("SHA-256").digest(decoded)
    }

    private companion object {
        private const val AES_GCM_TRANSFORMATION = "AES/GCM/NoPadding"
        private const val NONCE_BYTES = 12
        private const val TAG_BITS = 128
    }
}

data class EncryptedAppleRefreshToken(
    val ciphertext: String,
    val nonce: String
)
