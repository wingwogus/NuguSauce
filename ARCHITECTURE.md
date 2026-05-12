# NuguSauce Architecture

NuguSauce is a monorepo for a community iOS app around Haidilao-style sauce recipes.

## Repository Shape

```text
.
├── backend/   # Kotlin + Spring Boot API
├── ios/       # SwiftUI app, added when implementation starts
├── ops/       # Local and deployment harness, added when implementation starts
├── docs/      # Detailed knowledge and shared contracts
└── .omx/      # OMX plans, state, interviews, generated execution artifacts
```

## Current Backend

The backend is a Kotlin Spring Boot multi-module app:

- `api`: controllers, DTOs, security, Swagger, web adapters
- `application`: use cases, auth services, token issuing, external ports
- `domain`: entities, repositories, domain model

Current modules are declared in `backend/settings.gradle.kts` as `api`, `application`, and `domain`.

Backend package layout follows the Tribe project's feature-package convention:

- `api`: feature packages contain controllers and transport DTOs together, for example `com.nugusauce.api.auth` and `com.nugusauce.api.recipe`.
- `application`: feature packages contain commands, results, and services together, for example `com.nugusauce.application.recipe`.
- `domain`: domain feature packages contain entities and repositories together. Dense features may use role subpackages, for example `com.nugusauce.domain.recipe.sauce`, `recipe.ingredient`, `recipe.review`, `recipe.report`, and `recipe.favorite`.

Do not add new feature APIs under generic `api/controller` plus `api/dto` packages.

## Auth Boundary

The mobile-first social login flow is:

1. iOS creates a nonce before provider login.
2. iOS uses the Kakao SDK or native Sign in with Apple to obtain an OIDC token.
3. iOS calls `POST /api/v1/auth/kakao/login` or `POST /api/v1/auth/apple/login`.
4. Backend verifies provider issuer, audience, signature, expiry, issued-at, and nonce.
5. Backend returns NuguSauce access and refresh tokens.

The backend does not depend on Spring Security `oauth2Login` for the iOS app flow.

## Harness Boundary

Shared contracts live in `docs/contracts/` and must stay usable by both backend and iOS work:

- API envelopes and endpoint contracts
- Error shape
- Fixture schema and seed identity

Runtime checks and operator steps live in `docs/runbooks/`.

Product-level acceptance criteria remain in `.omx/plans/`.
