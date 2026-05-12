# NuguSauce Security Rules

Security-sensitive work includes auth, token handling, Kakao/Apple OIDC, user identity, review/report moderation, cookies, secrets, and personal data.

## Auth Rules

- iOS Kakao and Apple login must use nonce-backed OIDC ID token verification.
- Backend must verify issuer, audience, signature, expiry, issued-at, and nonce replay.
- Do not replace the mobile OIDC flow with web `oauth2Login` unless a new architecture decision is written.
- Refresh token handling must preserve replay and logout semantics.

## Token Rules

- Access tokens are bearer credentials.
- Refresh tokens must not be logged.
- Do not add token values to test snapshots, docs, fixtures, or final reports.
- Cookies must be reviewed for `httpOnly`, `secure`, `sameSite`, path, and lifetime.

## Secret Rules

- Do not commit real Kakao keys, Apple service/client secrets, JWT secrets, SMTP credentials, DB passwords, or Redis credentials.
- Use placeholders in docs and local examples.
- Treat `.env`, local YAML overrides, and deployment manifests as secret-adjacent files.

## PII Rules

- Fixture users must use fake emails and stable synthetic IDs.
- Public recipe/review fixtures should not include real user data.
- Moderation/reporting features must avoid exposing reporter identity in public APIs.

## Consent Rules

- Kakao and Apple login are identity proof only; they must not be treated as service-policy acceptance unless the current required policy versions are recorded for the member.
- iOS must not persist social-login issued NuguSauce sessions until required policy acceptance and required profile setup are both complete.
- Required consent evidence must store member id, policy version id, accepted timestamp, and source.
- Privacy, service terms, and content/photo rights policies gate image upload intent, recipe create, review create, report create, and profile image update.
- Public reads, Kakao login, Apple login, token reissue/logout, `GET /api/v1/members/me`, and consent status/accept endpoints must stay reachable before service-policy acceptance.
- When a required policy version changes, older acceptances do not satisfy the gate for that policy type.
