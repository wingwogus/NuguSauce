package com.nugusauce.domain.consent

enum class PolicyType(val wireValue: String) {
    TERMS_OF_SERVICE("terms_of_service"),
    PRIVACY_POLICY("privacy_policy"),
    CONTENT_POLICY("content_policy");

    companion object {
        fun fromWireValue(value: String): PolicyType? {
            val normalized = value.trim().lowercase()
            return values().firstOrNull { it.wireValue == normalized || it.name.lowercase() == normalized }
        }
    }
}
