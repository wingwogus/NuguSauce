# NuguSauce Security Rules

Security-sensitive work includes auth, token handling, Kakao OIDC, user identity, review/report moderation, cookies, secrets, and personal data.

## Auth Rules

- iOS Kakao login must use nonce-backed OIDC ID token verification.
- Backend must verify issuer, audience, signature, expiry, issued-at, and nonce replay.
- Do not replace the mobile OIDC flow with web `oauth2Login` unless a new architecture decision is written.
- Refresh token handling must preserve replay and logout semantics.

## Token Rules

- Access tokens are bearer credentials.
- Refresh tokens must not be logged.
- Do not add token values to test snapshots, docs, fixtures, or final reports.
- Cookies must be reviewed for `httpOnly`, `secure`, `sameSite`, path, and lifetime.

## Secret Rules

- Do not commit real Kakao keys, JWT secrets, SMTP credentials, DB passwords, or Redis credentials.
- Use placeholders in docs and local examples.
- Treat `.env`, local YAML overrides, and deployment manifests as secret-adjacent files.

## PII Rules

- Fixture users must use fake emails and stable synthetic IDs.
- Public recipe/review fixtures should not include real user data.
- Moderation/reporting features must avoid exposing reporter identity in public APIs.
