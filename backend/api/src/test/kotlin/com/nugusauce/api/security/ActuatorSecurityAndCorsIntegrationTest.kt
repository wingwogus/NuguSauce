package com.nugusauce.api.security

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.web.client.TestRestTemplate
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpMethod
import org.springframework.http.HttpStatus
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.header
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = [
        "app.url=https://nugusauce.jaehyuns.com",
        "management.server.port=0",
        "management.prometheus.metrics.export.enabled=true",
        "management.endpoints.web.exposure.include=health,prometheus",
        "management.endpoint.health.probes.enabled=true",
        "management.endpoint.prometheus.enabled=true",
        "management.health.redis.enabled=false",
        "spring.mail.username=test@example.com",
        "spring.mail.password=test-password"
    ]
)
@AutoConfigureMockMvc
@ActiveProfiles("local")
class ActuatorSecurityAndCorsIntegrationTest(
    @Autowired private val mockMvc: MockMvc,
    @Autowired private val restTemplate: TestRestTemplate,
    @Value("\${local.management.port}") private val managementPort: Int,
) {

    @Test
    fun `actuator health endpoints are public on the management port`() {
        val health = restTemplate.getForEntity("http://localhost:$managementPort/actuator/health", String::class.java)
        val liveness = restTemplate.getForEntity("http://localhost:$managementPort/actuator/health/liveness", String::class.java)
        val readiness = restTemplate.getForEntity("http://localhost:$managementPort/actuator/health/readiness", String::class.java)

        assertEquals(HttpStatus.OK, health.statusCode)
        assertEquals(HttpStatus.OK, liveness.statusCode)
        assertEquals(HttpStatus.OK, readiness.statusCode)
    }

    @Test
    fun `actuator prometheus endpoint is public on the management port`() {
        val prometheus = restTemplate.getForEntity("http://localhost:$managementPort/actuator/prometheus", String::class.java)

        assertEquals(HttpStatus.OK, prometheus.statusCode)
    }

    @Test
    fun `cors allows the configured production origin`() {
        mockMvc.perform(
            options("/api/v1/test/me")
                .header(HttpHeaders.ORIGIN, "https://nugusauce.jaehyuns.com")
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, HttpMethod.GET.name())
        )
            .andExpect(status().isOk)
            .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "https://nugusauce.jaehyuns.com"))
    }

    @Test
    fun `cors rejects unrelated origins`() {
        mockMvc.perform(
            options("/api/v1/test/me")
                .header(HttpHeaders.ORIGIN, "https://evil.example.com")
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, HttpMethod.GET.name())
        )
            .andExpect(status().isForbidden)
    }
}
