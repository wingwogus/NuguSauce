package com.nugusauce.api.controller

import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/test")
class TestController {

    @GetMapping("/ping")
    fun ping(): String {
        return "pong"
    }

    @GetMapping("/me")
    fun getMyInfo(@AuthenticationPrincipal userId: String): String {
        return "인증 성공, 현재 로그인한 유저의 ID(PK)는: $userId"
    }
}