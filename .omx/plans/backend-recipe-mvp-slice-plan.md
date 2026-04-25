# Backend Recipe MVP Slice Plan

Created: 2026-04-25T05:36:01Z
Mode: `$ralplan` consensus
Status: Approved by Critic after Architect iteration

## Requirements Summary

Plan a backend-first MVP slice for NuguSauce's Haidilao sauce recipe app.

The slice must support the product's core backend requirements:

- Anonymous users can browse popular/visible recipe lists and details.
- Kakao-authenticated users can create recipes.
- Authenticated users can add one rating/review per recipe.
- Recipe detail and list responses expose deterministic rating summary data.
- Hidden recipes are excluded from public surfaces and can be hidden/unhidden by an operator/admin.
- Search and filtering are available by keyword, taste tag, ingredient, spice level, and simple sort order.

Evidence:

- MVP success criteria require anonymous recipe browsing, Kakao-login recipe creation, reviews, rating summaries, and operator hiding (`.omx/plans/prd-nugusauce-v0.md:28`).
- MVP scope includes curated recipes, detail, user recipe creation, reviews, tags/ingredient search, and moderation (`.omx/plans/prd-nugusauce-v0.md:36`).
- Test spec requires canonical users, curated recipes, user recipes, ingredients, and reviews fixtures (`.omx/plans/test-spec-nugusauce-v0.md:14`).
- Fixture contract already names the first four user scenarios: anonymous list/detail, authenticated create, review, and hidden exclusion (`docs/contracts/fixtures.md:20`).
- Current backend has only `api`, `application`, and `domain` modules (`backend/settings.gradle.kts:3`).
- Recipe API contracts are explicitly not finalized yet and must be updated first (`docs/contracts/api.md:100`).

## RALPLAN-DR Summary

### Principles

1. Contract and fixture first: update shared API, error, and fixture docs before source implementation.
2. Preserve module boundaries: HTTP DTOs stay in `api`; commands/results and services stay in `application`; JPA entities/repositories stay in `domain`.
3. Public reads, protected mutations, admin-only moderation: anonymous `GET` is allowed only for visible recipe/ingredient/tag reads.
4. First slice proves four harness scenarios only: anonymous list/detail/search, authenticated create, authenticated review with rating summary, hidden recipe exclusion.
5. No new production dependencies: schema changes are local/test only until a migration mechanism is separately approved.

### Decision Drivers

1. Unblock the iOS five-screen prototype with stable JSON contracts.
2. Prove the core community rules with automated backend tests.
3. Minimize irreversible schema and API churn while the backend is still auth-focused.

### Viable Options

Option A: Contract-first narrow vertical slice.  
Implement recipe list/detail/search, create, review, reporting/moderation visibility, ingredients, and tags after contracts and fixtures are pinned.

Pros:

- Proves the product's core backend behavior.
- Gives iOS stable real endpoints instead of mocks.
- Keeps scope bounded enough for domain/application/API tests.

Cons:

- Defers favorites, full My Profile, binary image upload, and weekly/monthly batch ranking.
- Requires local/test JPA entities before a production migration strategy exists.

Option B: Contract/fixture-only, no backend implementation.

Pros:

- Fastest way to support UI mock development.
- Lowest persistence risk.

Cons:

- Does not prove auth, persistence, duplicate review, rating summary, or hidden exclusion behavior.
- Leaves the backend behind the iOS integration path.

Option C: Full backend platform now.

Pros:

- Covers future-facing features such as favorites, profile management, binary photos, batch rankings, production migrations, and richer admin tooling.

Cons:

- Too broad for the current MVP.
- Conflicts with the no-new-dependency and no-unapproved-migration constraints.
- Increases schema/API churn before product behavior is verified.

Decision: choose Option A.

## ADR

### Decision

Implement a narrow, contract-first backend vertical slice for recipe browsing, creation, review/rating summary, reporting, and admin visibility.

### Drivers

- Existing backend is auth-focused and recipe contracts are not finalized.
- The product's first usable loop depends on visible recipe browsing, authenticated creation, and review feedback.
- The repo requires deterministic fixtures and tests before broad feature expansion.

### Alternatives Considered

- Contract/fixture-only: rejected because it does not validate auth-protected mutation or persistence rules.
- Full backend platform: rejected because favorites, binary uploads, batch ranking, and production migrations are too broad for this slice.

### Why Chosen

The chosen slice gives the iOS app stable endpoints and gives the backend enough automated coverage to validate the community recipe loop without committing to larger platform decisions.

### Consequences

- First execution is local/test schema only.
- Dev/prod release is blocked until a migration strategy is approved.
- My Profile favorites, binary image upload, curated collection management, and true weekly/monthly ranking are follow-ups.

### Follow-ups

- Decide migration mechanism before dev/prod deployment.
- Add favorites and `GET /api/v1/me/recipes` / `GET /api/v1/me/favorite-recipes` after the core recipe/review slice passes.
- Decide image upload storage and file scanning policy before accepting binary uploads.
- Decide whether ranking remains query-based or moves to batch/materialized summaries.

## Implementation Plan

### 1. Contracts And Fixtures

Update [docs/contracts/api.md](/Users/wingwogus/Projects/NuguSauce/docs/contracts/api.md) before backend code.

Add contracts for:

- `GET /api/v1/recipes`
- `GET /api/v1/recipes/{recipeId}`
- `POST /api/v1/recipes`
- `GET /api/v1/ingredients`
- `GET /api/v1/tags`
- `POST /api/v1/recipes/{recipeId}/reviews`
- `GET /api/v1/recipes/{recipeId}/reviews`
- `POST /api/v1/recipes/{recipeId}/reports`
- `PATCH /api/v1/admin/recipes/{recipeId}/visibility`

Pin list/search parameters:

- `q`
- `tagIds`
- `ingredientIds`
- `spiceLevel`
- `sort=popular|recent|rating`

Pin sort semantics:

- `popular`: visible recipes ordered by review count descending, then average rating descending, then most recent review/creation.
- `recent`: visible recipes ordered by creation time descending.
- `rating`: visible recipes ordered by average rating descending, then review count descending.

Defer first-slice implementation of:

- `GET /api/v1/me/recipes`
- `GET /api/v1/me/favorite-recipes`
- `POST /api/v1/me/favorite-recipes/{recipeId}`
- `DELETE /api/v1/me/favorite-recipes/{recipeId}`

Rationale: My Profile and favorites are useful for the full five-screen plan, but they are not in the current MVP success criteria and would add persistence scope before the core recipe/review loop is verified.

Update [docs/contracts/errors.md](/Users/wingwogus/Projects/NuguSauce/docs/contracts/errors.md).

Add stable error codes for:

- recipe not found
- hidden recipe access
- ingredient not found
- tag not found
- duplicate review
- duplicate report
- invalid rating
- invalid ingredient amount/ratio
- forbidden admin action

Update [docs/contracts/fixtures.md](/Users/wingwogus/Projects/NuguSauce/docs/contracts/fixtures.md) and create `docs/fixtures/`.

Add JSON fixture examples for:

- users: normal, high-review, report-threshold, admin
- curated recipes: enough to prove list/detail/search, target 20 before full iOS smoke
- user recipes: enough to prove create/list behavior, target 10 before full iOS smoke
- ingredients master
- taste tags
- reviews with mixed ratings
- reports
- one hidden recipe

### 2. Schema Decision

This plan does not claim dev/prod deployment readiness.

Execution target:

- local/test JPA schema only
- no new migration dependency
- no dev/prod rollout until a separate migration decision is approved

Reason:

- local profile uses generated schema behavior.
- dev/prod profiles use `ddl-auto: none`.
- no migration directory or tool is currently part of the backend.

### 3. Domain Layer

Add package:

- `backend/domain/src/main/kotlin/com/nugusauce/domain/recipe/`

Initial types:

- `SauceRecipe`
- `RecipeIngredient`
- `Ingredient`
- `RecipeTag`
- `RecipeReview`
- `RecipeReport`
- `RecipeVisibility`
- `RecipeAuthorType`

Initial domain rules:

- recipe ingredients must be non-empty
- ingredient amount/ratio must be positive
- rating must be `1..5`
- hidden recipes are excluded from public reads
- one active review per member per recipe
- one report per member per recipe
- `SauceRecipe` stores `averageRating`, `reviewCount`, and `lastReviewedAt`
- adding a first review updates rating summary deterministically

Repository style:

- follow existing Spring Data JPA repository interfaces
- prefer explicit repository methods and simple JPQL for filtering/ranking
- do not add QueryDSL or other production dependencies

### 4. Application Layer

Add package:

- `backend/application/src/main/kotlin/com/nugusauce/application/recipe/`

Add grouped use-case models:

- `RecipeCommand.kt`
- `RecipeResult.kt`

Add services grouped by behavior:

- `RecipeQueryService`
- `RecipeWriteService`
- `RecipeReviewService`
- `RecipeModerationService`

Service responsibilities:

- map user IDs from JWT principal to member-scoped use cases
- enforce validation beyond DTO annotations
- reject duplicate reviews/reports
- reject public access to hidden recipes using documented error semantics
- keep reporter identity out of public result models
- expose stable list/detail/review results for API mapping

### 5. API And Security Layer

Add DTO groups:

- `backend/api/src/main/kotlin/com/nugusauce/api/recipe/RecipeRequests.kt`
- `backend/api/src/main/kotlin/com/nugusauce/api/recipe/RecipeResponses.kt`

Add controllers:

- `backend/api/src/main/kotlin/com/nugusauce/api/recipe/RecipeController.kt`
- `backend/api/src/main/kotlin/com/nugusauce/api/recipe/AdminRecipeController.kt`

Keep `ApiResponse` unchanged.

Update:

- [backend/application/src/main/kotlin/com/nugusauce/application/exception/ErrorCode.kt](/Users/wingwogus/Projects/NuguSauce/backend/application/src/main/kotlin/com/nugusauce/application/exception/ErrorCode.kt)
- [backend/api/src/main/kotlin/com/nugusauce/config/SecurityConfig.kt](/Users/wingwogus/Projects/NuguSauce/backend/api/src/main/kotlin/com/nugusauce/config/SecurityConfig.kt)

Security rules:

- permit anonymous `GET /api/v1/recipes`
- permit anonymous `GET /api/v1/recipes/{recipeId}`
- permit anonymous `GET /api/v1/ingredients`
- permit anonymous `GET /api/v1/tags`
- require authentication for `POST /api/v1/recipes`
- require authentication for review/report mutation routes
- require admin authority for `/api/v1/admin/**`
- use `hasAuthority("ROLE_ADMIN")` or `hasRole("ADMIN")`, not `hasRole("ROLE_ADMIN")`

### 6. Tests First

Write focused tests before or alongside implementation.

Domain tests:

- rating summary average/count update
- rating boundary `1..5`
- invalid ingredient amount/ratio
- hidden visibility behavior

Application tests:

- authenticated member creates a recipe
- review creation updates summary
- duplicate review is rejected
- duplicate report is rejected
- hidden recipe is excluded from public list/detail

API/controller tests:

- documented response examples match actual JSON envelope
- validation errors use the documented failure envelope
- anonymous `GET` recipe/ingredient/tag routes are public
- missing JWT rejects create/review/report mutations
- `ROLE_USER` cannot patch admin visibility
- `ROLE_ADMIN` can patch admin visibility

Security integration tests:

- extend the current auth security pattern to method-specific public `GET` and protected mutation checks
- prove admin authorization through existing JWT authority mapping

## Acceptance Criteria

- API, error, and fixture docs are updated before source implementation.
- Contracts include examples for the four first-slice harness scenarios.
- Anonymous users can list/search/detail visible recipes.
- Hidden recipe list/detail behavior is stable and documented.
- Authenticated users can create a recipe.
- Authenticated users can create exactly one review per recipe.
- Rating summary updates deterministically after review creation.
- Report creation requires auth and duplicate reports are rejected.
- Admin can hide/unhide recipes.
- Public queries exclude hidden recipes.
- Mutating recipe endpoints reject missing or invalid JWT.
- Admin route rejects `ROLE_USER`.
- No new production dependency is added.
- The completion report states that dev/prod migration is not ready until the migration follow-up is decided.

## Verification

Run from `backend/`:

```bash
./gradlew :domain:test :application:test :api:test
```

Then run:

```bash
./gradlew test
```

Completion evidence must include:

- commands run
- pass/fail result
- skipped checks and reason
- known residual risk

## Risks And Mitigations

Risk: schema drift before migration tooling exists.  
Mitigation: limit first execution to local/test schema and record migration as a release blocker.

Risk: public matcher accidentally exposes mutation endpoints.  
Mitigation: use method-specific security matchers and integration tests for public `GET` versus protected `POST/PATCH/DELETE`.

Risk: ranking semantics become vague and untestable.  
Mitigation: pin `popular`, `recent`, and `rating` order in the API contract before implementation.

Risk: DTO/service sprawl.  
Mitigation: group recipe requests/responses and command/result types conservatively.

Risk: moderation leaks reporter identity.  
Mitigation: keep reporter identity out of public API results and document the security boundary.

## Available Agent Types Roster

Relevant execution roles:

- `executor`: implement domain/application/API slice.
- `test-engineer`: write and harden domain/application/API/security tests.
- `architect`: review schema, security boundary, and module separation if scope expands.
- `security-reviewer`: review admin/reporting/auth exposure.
- `verifier`: validate completion evidence and test adequacy.
- `writer`: update API/error/fixture docs if split from implementation.

## Staffing Guidance

Sequential `$ralph` path:

- Use one `executor` as the owner for the full slice.
- Add `test-engineer` only if test design starts blocking implementation.
- Add `security-reviewer` before final handoff if admin/reporting behavior changes.
- Finish with `verifier` after Gradle checks pass.

Parallel `$team` path:

- Lane 1, `writer`: API/error/fixture contracts and fixture JSON.
- Lane 2, `executor`: domain model and repositories.
- Lane 3, `executor`: application services and commands/results.
- Lane 4, `executor`: API controllers/DTOs/security.
- Lane 5, `test-engineer`: domain/application/API/security tests.
- Lane 6, `security-reviewer` or `verifier`: admin/reporting/JWT boundary review after implementation joins.

Write scopes must stay disjoint until integration:

- docs lane owns `docs/contracts/*` and `docs/fixtures/*`
- domain lane owns `backend/domain/src/*`
- application lane owns `backend/application/src/main/*`
- API lane owns `backend/api/src/main/*`
- test lane owns `backend/*/src/test/*`

## Launch Hints

Ralph:

```bash
omx ralph "Execute .omx/plans/backend-recipe-mvp-slice-plan.md. Keep implementation to local/test backend MVP slice; do not add production dependencies; run backend Gradle verification before completion."
```

Team:

```bash
omx team 5:executor "Implement .omx/plans/backend-recipe-mvp-slice-plan.md with lanes for docs/fixtures, domain, application, API/security, and tests. Keep write scopes disjoint and verify with backend Gradle checks."
```

## Team Verification Path

Before team shutdown:

- contracts and fixtures exist and match implemented JSON
- all domain/application/API test lanes are green independently
- security lane proves anonymous public reads and protected mutations
- no lane added an unapproved production dependency

After team handoff, Ralph or the leader verifies:

- full `./gradlew test` from `backend/`
- final diff follows module boundaries
- completion report includes migration limitation and remaining follow-ups

## Applied Review Improvements

- Narrowed first execution from broad recipe/profile/favorite platform to four harness scenarios.
- Added explicit local/test-only schema decision and dev/prod migration follow-up.
- Required `docs/contracts/errors.md` updates alongside `api.md`.
- Made method/path security matcher requirements explicit.
- Added admin authority testing guidance.
- Deferred favorites and My Profile endpoints from first implementation.
- Added sort semantics so ranking behavior is testable.
