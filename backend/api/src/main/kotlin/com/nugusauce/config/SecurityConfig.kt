package com.nugusauce.config

import com.nugusauce.api.security.CustomAccessDeniedHandler
import com.nugusauce.api.security.CustomAuthenticationEntryPoint
import com.nugusauce.api.security.JwtAuthenticationFilter
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.web.servlet.FilterRegistrationBean
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.http.HttpMethod
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity
import org.springframework.security.config.http.SessionCreationPolicy
import org.springframework.security.web.SecurityFilterChain
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter
import org.springframework.web.cors.CorsConfiguration


@Configuration
@EnableWebSecurity
class SecurityConfig(
    private val accessDeniedHandler: CustomAccessDeniedHandler,
    private val authenticationEntryPoint: CustomAuthenticationEntryPoint,
    private val jwtAuthenticationFilter: JwtAuthenticationFilter,
    private val mdcLoggingFilter: MDCLoggingFilter,
    @Value("\${app.url:http://localhost:8081}") private val appUrl: String,
) {

    companion object {
        private val PUBLIC_ENDPOINTS = listOf(
            "/swagger-ui/**",
            "/v3/api-docs/**",
            "/actuator/health",
            "/actuator/health/**",
            "/actuator/prometheus",
            "/api/v1/auth/email/send-code",
            "/api/v1/auth/email/verify-code",
            "/api/v1/auth/signup",
            "/api/v1/auth/login",
            "/api/v1/auth/kakao/login",
            "/api/v1/auth/apple/login",
            "/api/v1/auth/reissue",
            "/error",                // 스프링 내부 오류 페이지
        )

        private val PUBLIC_GET_ENDPOINTS = listOf(
            "/api/v1/home",
            "/api/v1/recipes",
            "/api/v1/recipes/*",
            "/api/v1/recipes/*/reviews",
            "/api/v1/ingredients",
            "/api/v1/tags",
            "/api/v1/members/*",
        )
    }

    @Bean
    fun securityFilterChain(http: HttpSecurity): SecurityFilterChain {

        http
            .csrf { it.disable() }
            .formLogin { it.disable() }
            .httpBasic { it.disable() }

            .cors {
                it.configurationSource {
                    CorsConfiguration().apply {
                        allowedOrigins = listOf(appUrl)
                        allowedMethods = listOf("*")
                        allowedHeaders = listOf("*")
                        allowCredentials = true
                    }
                }
            }

            .sessionManagement {
                it.sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            }

            .exceptionHandling {
                it.authenticationEntryPoint(authenticationEntryPoint)
                it.accessDeniedHandler(accessDeniedHandler)
            }

            .authorizeHttpRequests {
                it
                    .requestMatchers(*PUBLIC_ENDPOINTS.toTypedArray())
                    .permitAll()
                    .requestMatchers(HttpMethod.GET, "/api/v1/members/me")
                    .authenticated()
                    .requestMatchers(HttpMethod.GET, *PUBLIC_GET_ENDPOINTS.toTypedArray())
                    .permitAll()
                    .requestMatchers("/api/v1/admin/**")
                    .hasAuthority("ROLE_ADMIN")
                    .anyRequest().authenticated()
            }

            .addFilterBefore(
                jwtAuthenticationFilter,
                UsernamePasswordAuthenticationFilter::class.java
            )
            .addFilterAfter(
                mdcLoggingFilter,
                UsernamePasswordAuthenticationFilter::class.java
            )

        return http.build()
    }

    @Bean
    fun mdcLoggingFilterRegistration(mdcLoggingFilter: MDCLoggingFilter): FilterRegistrationBean<MDCLoggingFilter> {
        return FilterRegistrationBean<MDCLoggingFilter>().apply {
            filter = mdcLoggingFilter
            isEnabled = false
        }
    }

}
