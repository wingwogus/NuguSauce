# NuguSauce Backend

Kotlin Spring Boot backend for NuguSauce.

This backend was initialized from `/Users/wingwogus/IdeaProjects/springboot-kotlin-initial-template` on the `auth-kakao-sdk-oidc-app` branch. It keeps the mobile-first Kakao SDK OIDC login flow and starts with the modules needed for the MVP.

## Modules

* `api`: Spring Boot entrypoint, controllers, security, DTOs, Swagger, web adapters
* `application`: use cases, token issuing, Kakao OIDC verification, Redis-backed auth state
* `domain`: JPA entities, repositories, domain model

The template `batch` module was intentionally not imported for the first MVP.

## Kakao SDK OIDC App Login

The backend does not expose or rely on Spring Security `oauth2Login`, `/oauth2/authorization/kakao`, or `/login/oauth2/code/kakao`.

App flow:

1. Generate a cryptographically random nonce before Kakao login.
2. Call Kakao SDK `loginWithKakaoTalk()` and fall back to `loginWithKakaoAccount()`.
3. Request OIDC so Kakao returns an ID token containing the nonce.
4. Call `POST /api/v1/auth/kakao/login`.

```json
{
  "idToken": "<kakao_oidc_id_token>",
  "nonce": "<client_generated_nonce>"
}
```

The backend verifies Kakao JWKS-backed signature, issuer, audience, expiry, issued-at, and nonce, then stores the nonce with Redis SETNX semantics to prevent replay. It returns NuguSauce service `accessToken` and `refreshToken` in the response body for iOS Keychain storage.

Required config:

```yaml
auth:
  kakao:
    oidc:
      issuer: https://kauth.kakao.com
      audience: ${KAKAO_NATIVE_APP_KEY}
      discovery-uri: https://kauth.kakao.com/.well-known/openid-configuration
      allowed-clock-skew-seconds: 60
      nonce-replay-ttl-seconds: 600
```

## Schema Rollout

The imported OIDC branch expects these auth schema capabilities:

* `member.password_hash` must be nullable.
* `external_identity` stores `member_id`, `provider`, `provider_subject`, and `email_at_link_time`.
* `(provider, provider_subject)` must be unique.

Flyway is not included yet. NuguSauce should add migrations when the production database choice is finalized.

## Run

```bash
./gradlew :api:bootRun
```

Run tests:

```bash
./gradlew test
```
