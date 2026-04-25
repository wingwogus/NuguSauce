package com.nugusauce.application.config

import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.mail.javamail.JavaMailSender
import org.springframework.mail.javamail.JavaMailSenderImpl
import java.util.Properties
import kotlin.apply
import kotlin.collections.set

@Configuration
class EmailConfig(
    @Value("\${spring.mail.host}") private val host: String,
    @Value("\${spring.mail.port}") private val port: Int,
    @Value("\${spring.mail.username}") private val username: String,
    @Value("\${spring.mail.password}") private val password: String,
    @Value("\${spring.mail.properties.mail.smtp.auth}") private val auth: Boolean,
    @Value("\${spring.mail.properties.mail.smtp.starttls.enable}") private val starttlsEnable: Boolean,
    @Value("\${spring.mail.properties.mail.smtp.starttls.required}") private val starttlsRequired: Boolean,
    @Value("\${spring.mail.properties.mail.smtp.connectiontimeout}") private val connectionTimeout: Int,
    @Value("\${spring.mail.properties.mail.smtp.timeout}") private val timeout: Int,
    @Value("\${spring.mail.properties.mail.smtp.writetimeout}") private val writeTimeout: Int
) {

    @Bean
    fun javaMailSender(): JavaMailSender {
        return JavaMailSenderImpl().apply {
            this.host = this@EmailConfig.host
            this.port = this@EmailConfig.port
            this.username = this@EmailConfig.username
            this.password = this@EmailConfig.password
            this.defaultEncoding = "UTF-8"
            this.javaMailProperties = getMailProperties()
        }
    }

    private fun getMailProperties(): Properties {
        return Properties().apply {
            put("mail.smtp.auth", auth.toString())
            put("mail.smtp.starttls.enable", starttlsEnable.toString())
            put("mail.smtp.starttls.required", starttlsRequired.toString())
            put("mail.smtp.connectiontimeout", connectionTimeout.toString())
            put("mail.smtp.timeout", timeout.toString())
            put("mail.smtp.writetimeout", writeTimeout.toString())
        }
    }
}
