package com.nugusauce.application.auth

interface EmailSender {
    fun sendVerificationCode(email: String, code: String)
}
