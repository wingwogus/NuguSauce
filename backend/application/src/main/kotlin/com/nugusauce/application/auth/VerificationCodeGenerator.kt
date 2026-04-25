package com.nugusauce.application.auth

interface VerificationCodeGenerator {
    fun generate(): String
}
