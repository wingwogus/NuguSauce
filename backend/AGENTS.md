# Backend Agent Guide

This file applies to backend work. If Codex was launched from repo root, read this file manually before touching `backend/`.

## Stack

- Kotlin `1.9.25`
- Spring Boot `3.5.4`
- Java toolchain `21`
- Gradle multi-module project under `backend/`
- Modules: `api`, `application`, `domain`

## Required Context

- Product plan: `../.omx/plans/prd-nugusauce-v0.md`
- Test plan: `../.omx/plans/test-spec-nugusauce-v0.md`
- API contracts: `../docs/contracts/api.md`
- Error shape: `../docs/contracts/errors.md`
- Fixtures: `../docs/contracts/fixtures.md` when seed/test data changes
- Security: `../SECURITY.md` for auth, token, identity, or PII changes

## Backend Harness Rules

- Add or update tests before broad feature expansion.
- Keep tests at the narrowest useful layer: domain, application, API/controller, then integration.
- Keep API response shapes aligned with `docs/contracts/api.md` and `docs/contracts/errors.md`.
- Follow the Tribe-style feature package layout:
  - `api`: group HTTP controllers and DTOs by feature, e.g. `com.nugusauce.api.auth.AuthController`, `AuthRequests`, `AuthResponses`; do not create separate `api/controller` and `api/dto` trees for new feature APIs.
  - `application`: group use-case models/services by feature, e.g. `com.nugusauce.application.recipe.RecipeCommand`, `RecipeResult`, `RecipeQueryService`.
  - `domain`: group entities/repositories by domain feature, and split dense features by role subpackage when it improves navigation, e.g. `com.nugusauce.domain.recipe.sauce.SauceRecipe`, `recipe.ingredient.Ingredient`, `recipe.review.RecipeReview`.
- Keep HTTP DTOs in the `api` module as `*Requests` / `*Responses`; keep use-case models in the `application` module as `*Command` / `*Result`.
- Do not over-split backend classes or files. Keep related DTOs, commands, results, and private helpers together until there is real complexity, reuse, dependency injection, or ownership pressure.
- Keep test data deterministic; update `docs/contracts/fixtures.md` when fixture identity or semantics change.
- Do not add a new dependency without explicit user request.

## Commands

Run from `backend/`:

```bash
./gradlew test
```

Focused checks:

```bash
./gradlew :application:test
./gradlew :api:test
```

Use `./gradlew :api:bootRun` only when local runtime behavior must be inspected.

## Auth Boundary

The iOS Kakao login path is `POST /api/v1/auth/kakao/login` with an OIDC ID token and nonce. Do not introduce web redirect OAuth as the primary mobile auth path without updating `.omx/plans/` and `SECURITY.md`.
