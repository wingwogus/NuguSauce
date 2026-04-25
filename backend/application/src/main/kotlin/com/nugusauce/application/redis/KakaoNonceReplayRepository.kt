package com.nugusauce.application.redis

import java.time.Duration

interface KakaoNonceReplayRepository {
    fun reserve(nonce: String, ttl: Duration): Boolean
}
