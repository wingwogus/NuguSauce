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

## Commit Convention

- Follow the repository root commit convention for backend changes.
- Use `<type>: {변경사항 한국어 동작 구문}` and choose the type by the actual backend change:
  - `feat`: 새로운 기능 추가
  - `fix`: 버그 수정
  - `docs`: 문서 수정
  - `refactor`: 기능 변경 없는 코드 리팩토링
  - `test`: 테스트 코드 추가 또는 수정
  - `chore`: 빌드, 패키지 매니저 설정 등 기타 잡일
- Keep the Korean subject after `<type>:` short, but include an action word when it makes the change clearer, e.g. `백엔드 커밋 타입 규칙 수정`; do not use sentence endings such as `~한다`.

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
