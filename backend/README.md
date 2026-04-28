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
3. Request OIDC plus `account_email` consent so Kakao returns an ID token and an access token that can read OIDC userinfo.
4. Call `POST /api/v1/auth/kakao/login`.

```json
{
  "idToken": "<kakao_oidc_id_token>",
  "nonce": "<client_generated_nonce>",
  "kakaoAccessToken": "<kakao_oauth_access_token>"
}
```

The backend verifies Kakao JWKS-backed signature, issuer, audience, expiry, issued-at, and nonce, then calls Kakao OIDC userinfo to confirm the subject and verified email before storing the nonce with Redis SETNX semantics to prevent replay. It returns NuguSauce service `accessToken` and `refreshToken` in the response body for iOS Keychain storage.

Required config:

```yaml
auth:
  kakao:
    oidc:
      issuer: https://kauth.kakao.com
      audience: ${KAKAO_NATIVE_APP_KEY}
      discovery-uri: https://kauth.kakao.com/.well-known/openid-configuration
      user-info-uri: https://kapi.kakao.com/v1/oidc/userinfo
      allowed-clock-skew-seconds: 60
      nonce-replay-ttl-seconds: 600
```

## Schema Rollout

The imported OIDC branch expects these auth schema capabilities:

* `member.password_hash` must be nullable.
* `member.nickname` must be nullable and limited to 20 characters.
* `member.nickname` must have a unique constraint named `uk_member_nickname`.
* `external_identity` stores `member_id`, `provider`, `provider_subject`, and `email_at_link_time`.
* `(provider, provider_subject)` must be unique.

Flyway is not included yet. Production deployment now targets PostgreSQL to match the ops stack.

Until a migration tool is added, apply this manual PostgreSQL rollout before deploying member profile endpoints to any `dev` or `prod` database:

```sql
ALTER TABLE member
    ADD COLUMN nickname VARCHAR(20) NULL;

ALTER TABLE member
    ADD CONSTRAINT uk_member_nickname UNIQUE (nickname);
```

Rollback:

```sql
ALTER TABLE member
    DROP CONSTRAINT uk_member_nickname;

ALTER TABLE member
    DROP COLUMN nickname;
```

## Deployment

The backend deploys with the same shape as the Tribe API:

* Build jar: `./gradlew --no-daemon clean :api:bootJar`
* Build image from `backend/Dockerfile`
* Publish image: `docker.io/vantagac/nugusauce-api:<git-sha>`
* Deploy chart: `ops/helm/nugusauce-api`
* Public API origin: `https://nugusauce.jaehyuns.com`

Production exposes app traffic on port `8080` and actuator health/Prometheus on management port `9090`.

## Run

```bash
./gradlew :api:bootRun
```

Run tests:

```bash
./gradlew test
```
