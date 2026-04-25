# NuguSauce iOS Five-Screen Plan v0

## Status

Ralplan consensus: approved.

- Planner draft: complete.
- Architect review: iterated once, then approved.
- Critic review: approved with minor execution-time recommendations.

This is a planning artifact only. It does not approve adding new production dependencies.

## Task

Build the initial iOS app shape for five user-facing areas:

1. Home
2. Recipe Detail
3. Create Recipe
4. Search & Categories
5. My Profile and public other-user page surface

## Principles

- Contract first: iOS behavior must decode and follow `docs/contracts/api.md`, `docs/contracts/errors.md`, and `docs/contracts/fixtures.md`.
- Mock first: use `docs/fixtures/nugusauce-mvp.json` for fixture-backed development before relying on live backend behavior.
- Single SwiftUI project first: start with one Xcode project and clear folders instead of early SPM modularization.
- No unapproved dependency: Kakao SDK and any image upload SDK require explicit approval before implementation.
- Security boundary: tokens must never be logged, snapshotted, fixture-stored, or included in reports.

## Decision Drivers

1. The `ios/` tree is currently empty, so fast scaffold plus clear boundaries is more valuable than early module splitting.
2. MVP verification already centers on four contract-backed flows: anonymous list/detail, authenticated create, authenticated review, and hidden recipe exclusion.
3. Some requested UI concepts do not yet have API contracts, especially public profile details and photo upload.

## Options Considered

### Option A: Contract-first single SwiftUI project

Use one Xcode project with `App`, `Core`, `Features`, `Shared`, and `Resources`.

Pros:

- Matches the repo PRD and iOS guide.
- Fast to scaffold.
- Keeps ViewModel and XCUITest harness straightforward.
- Avoids new dependency and package decisions.

Cons:

- Boundaries rely on discipline until the app is large enough to justify modules.

### Option B: SPM modularized iOS architecture

Split Core, Features, and Shared into Swift packages immediately.

Pros:

- Strong compile-time boundaries.
- Easier long-term ownership separation.

Cons:

- Too much setup overhead while `ios/` is empty.
- Slows MVP harness work.
- Adds architectural ceremony before the product flows are proven.

### Option C: Fast single-file prototype

Build screens quickly with minimal folders and minimal ViewModel separation.

Pros:

- Fastest first pixels.

Cons:

- Weak testability.
- Easy to mix request DTOs, response DTOs, fixture models, and view state.
- Poor fit for the harness-first rule.

## Decision

Choose Option A: a contract-first single SwiftUI Xcode project.

The initial structure should be:

```text
ios/
├── NuguSauce.xcodeproj
├── NuguSauce/
│   ├── App/
│   ├── Core/
│   │   ├── API/
│   │   ├── Auth/
│   │   ├── Fixtures/
│   │   └── Models/
│   ├── Features/
│   │   ├── Home/
│   │   ├── RecipeDetail/
│   │   ├── CreateRecipe/
│   │   ├── Search/
│   │   └── Profile/
│   ├── Shared/
│   └── Resources/
├── NuguSauceTests/
└── NuguSauceUITests/
```

## Completion Levels

Use two completion labels during implementation:

- Contract-backed complete: behavior is supported by an existing API contract, fixture, and automated test or documented smoke check.
- Visible placeholder complete: route or UI shell exists, but data or mutation behavior is intentionally deferred until a contract or dependency approval exists.

## Screen Scope

### 1. Home

Contract-backed complete:

- Load public recipes from `GET /api/v1/recipes`.
- Support `popular`, `recent`, and `rating` sort values.
- Provide a search entry point into Search & Categories.
- Ensure hidden recipes are not shown in public lists.

ViewModel:

- `HomeViewModel`
- State: loading, loaded recipes, empty, error, selected sort.

Primary tests:

- Recipe card state.
- Sort state.
- Hidden recipe exclusion with fixture/mock data.
- Anonymous XCUITest: Home list to Recipe Detail.

### 2. Recipe Detail

Contract-backed complete:

- Load recipe detail from `GET /api/v1/recipes/{recipeId}`.
- Load reviews separately from `GET /api/v1/recipes/{recipeId}/reviews`.
- Display ingredients, amount/unit/ratio, tips, rating summary, review tags, and reviews.
- Gate review creation behind auth.
- Submit review to `POST /api/v1/recipes/{recipeId}/reviews`.

Favorite scope:

- Detail may show favorite state only after deriving it from authenticated `/me/favorite-recipes` cache.
- Favorite POST/DELETE from detail is a phase-2 interaction unless the implementation first wires the authenticated favorite cache and error handling.
- My Profile favorite management is the first contract-backed favorite management surface.

ViewModel:

- `RecipeDetailViewModel`
- Keep detail state, reviews state, review composer state, and favorite overlay state separate.

Primary tests:

- Detail/reviews loading state.
- Rating input state.
- Duplicate review and auth error branching by stable API error code.
- Authenticated XCUITest: submit review.

### 3. Create Recipe

Contract-backed complete:

- Auth-gated form for title, description, tips, and ingredients.
- Ingredient inputs support `ingredientId`, `amount`, `unit`, and `ratio`.
- Submit `POST /api/v1/recipes`.
- Use a dedicated create request DTO. Do not reuse fixture or response DTOs.
- Do not send `spiceLevel`, `richnessLevel`, or `tagIds`; current create contract rejects author-selected taste classification.

Visible placeholder complete:

- A local photo preview affordance may exist, but upload is not implemented.
- Submitted `imageUrl` remains `nil` until an upload contract exists.

ViewModel:

- `CreateRecipeViewModel`
- State: fields, ingredient rows, validation errors, submit state, auth gate.

Primary tests:

- Form validation.
- Request DTO does not include forbidden classification fields.
- Auth gate state.
- Authenticated XCUITest: create recipe with fixture/mock auth.

### 4. Search & Categories

Contract-backed complete:

- Load ingredients from `GET /api/v1/ingredients`.
- Load tags from `GET /api/v1/tags`.
- Compose `q`, `tagIds`, `ingredientIds`, and `sort` filters.
- Load recipe results with the same list endpoint used by Home.

ViewModel:

- `SearchViewModel`
- State: query, selected tags, selected ingredients, sort, results, loading/error.

Primary tests:

- Filter combination changes.
- Query reset.
- Ingredient/tag decoding.

### 5. My Profile And Public Profile Surface

Contract-backed complete:

- My Profile loads authored recipes from `GET /api/v1/me/recipes`.
- My Profile loads saved recipes from `GET /api/v1/me/favorite-recipes`.
- My Profile can manage saved recipes through the favorite contract, starting with removing a favorite from the saved list.
- Auth state is visible and recoverable through `AuthSessionStoreProtocol`.

Visible placeholder complete:

- Public other-user page is limited to `AppRoute.publicProfile(userId)` and a placeholder view.
- Do not create a public profile network service until a public user/profile API contract exists.

ViewModel:

- `ProfileViewModel`
- State: auth session, my recipes, favorite recipes, profile tabs, loading/error.

Primary tests:

- Auth session restore.
- My recipes/favorites loading.
- Favorite removal behavior when implemented.
- Public profile route renders placeholder without network dependency.

## Navigation

- `RootTabView`: Home, Search, Create, Profile.
- `NavigationStack` per tab is acceptable for the first scaffold.
- Shared route enum:
  - `AppRoute.recipeDetail(id)`
  - `AppRoute.publicProfile(userId)`
  - `AppRoute.loginRequired`

Create Recipe should be a tab because recipe registration is a primary product action, but it must render a login-required state when no session is available.

## Data And Core Boundaries

### Core/API

- `ApiEnvelope<T>` for `success`, `data`, and `error`.
- `ApiError` for `code`, `message`, and `detail`.
- `APIClientProtocol` for real and mock API clients.
- `RecipeServiceProtocol`, `IngredientServiceProtocol`, `TagServiceProtocol`, `ProfileServiceProtocol`, and `AuthServiceProtocol`.
- Stable error-code branching should use `docs/contracts/errors.md`.

### Core/Auth

- `AuthSession`
- `AuthSessionStoreProtocol`
- `MockAuthSessionStore`
- Future `KeychainAuthSessionStore`
- Future Kakao adapter after explicit SDK approval.

The final auth target remains:

1. iOS creates a nonce.
2. Kakao SDK returns an OIDC ID token.
3. iOS calls `POST /api/v1/auth/kakao/login`.
4. Backend returns NuguSauce access and refresh tokens.

Phase 1 must model this state transition without adding the Kakao SDK.

### Core/Models

Separate:

- Response DTOs
- Request DTOs
- Fixture DTOs
- View display models

Do not use fixture recipe models as create request models.

### Core/Fixtures

- Load `docs/fixtures/nugusauce-mvp.json`.
- Fixture data must keep fake users and synthetic IDs.
- Fixture tokens should not exist.

## Implementation Phases

### Phase 1: Scaffold

- Create Xcode project, app target, unit test target, and UI test target.
- Add folder structure.
- Add root tab and placeholder screens.
- Add route enum.

Done when:

- App launches to the tab shell.
- Unit and UI test targets run.

### Phase 2: Contract Models And Mock API

- Add envelope/error decoding.
- Add DTOs for recipe summary, detail, ingredient, tag, review, favorite, my recipes, and create request.
- Add fixture-backed mock API client.

Done when:

- Fixture recipes decode.
- Hidden recipe exclusion can be tested.
- Error-code branching can be tested.

### Phase 3: Read-Only Product Loop

- Home list.
- Recipe Detail.
- Search & Categories.

Done when:

- Anonymous Home to Detail XCUITest passes.
- Hidden recipes do not appear.

### Phase 4: Auth-Gated Product Loop

- Mock auth session.
- Auth session restore.
- Create Recipe form and submit state.
- Review composer and submit state.
- Token redaction/no snapshot leaks tests.

Done when:

- Authenticated create XCUITest passes with mock auth.
- Authenticated review XCUITest passes with mock auth.
- Token values are not logged or snapshotted.

### Phase 5: Profile And Favorite Management

- My recipes.
- Favorite recipes.
- Remove favorite from saved list.
- Public profile placeholder route.

Done when:

- Profile loads my recipes and favorites from fixture/mock services.
- Favorite removal is covered if implemented.
- Public profile route does not depend on a nonexistent API.

### Phase 6: Real Backend And Kakao Follow-Up

Only after explicit approval for the Kakao SDK and runtime wiring:

- Add Kakao SDK.
- Add nonce-backed OIDC login adapter.
- Add secure token persistence.
- Point services to local backend.

This phase is not part of the initial five-screen scaffold approval.

## Test Plan

### Unit And State Tests

- `ApiEnvelope<T>` success decode.
- `ApiEnvelope<T>` failure decode.
- Stable error-code branching for `AUTH_*`, `COMMON_*`, and `RECIPE_*`.
- Recipe card display state.
- Rating input state.
- Search filter composition state.
- Create form validation.
- Create request DTO excludes `spiceLevel`, `richnessLevel`, and `tagIds`.
- Auth session restore.
- Kakao token exchange state machine with mock token values.
- Token redaction/no snapshot leakage.
- Hidden recipe exclusion.

### XCUITest Smoke

- Anonymous user opens Home and enters Recipe Detail.
- Authenticated mock user creates a recipe.
- Authenticated mock user leaves rating and review.
- Hidden recipe does not appear in public list/search.

### Verification Commands

Concrete commands should be finalized after the Xcode project exists. Initial target:

```sh
xcodebuild test -project ios/NuguSauce.xcodeproj -scheme NuguSauce -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project ios/NuguSauce.xcodeproj -scheme NuguSauceUITests -destination 'platform=iOS Simulator,name=iPhone 16'
rg -n "accessToken|refreshToken|idToken" ios/NuguSauceTests ios/NuguSauceUITests ios/NuguSauce
```

If simulator names differ locally, use `xcodebuild -list` and `xcrun simctl list devices available` to select the available destination.

## Acceptance Criteria

- The app has five visible screen areas matching the requested product surface.
- Contract-backed behavior never relies on an API that is not in `docs/contracts/api.md`.
- Public Profile is explicitly placeholder-only until a public profile contract exists.
- Photo upload is explicitly placeholder-only until an upload contract exists.
- Create Recipe does not submit author-selected taste classification fields.
- Response envelope and error shape are decoded through shared Core/API code.
- ViewModels own feature state and are unit-testable.
- The four MVP XCUITest scenarios from the test spec have corresponding test cases or documented smoke steps.
- No token values appear in logs, fixtures, snapshots, test names, or final reports.

## Risks And Follow-Ups

- Public profile API missing: add a backend/iOS contract before implementing real 상대페이지 data.
- Upload contract missing: add upload endpoint and storage/security decision before enabling photo upload.
- Detail favorite viewer state missing: either derive from `/me/favorite-recipes` cache or add a contract field later.
- Kakao SDK dependency: requires explicit approval and a security review before adding.
- Design system unspecified: start with minimal shared components and defer visual QA baseline until Home, Detail, and Create stabilize.

## ADR

Decision: Start NuguSauce iOS as a contract-first single SwiftUI Xcode project with five visible screen areas and strict completion labels.

Drivers:

- The iOS app has not been scaffolded yet.
- The MVP is already contract and fixture driven.
- Harness rules require ViewModel/unit/UI test coverage before broad UI expansion.

Alternatives considered:

- SPM modularization first: rejected because the setup cost is high before the app has stable product boundaries.
- Single-file prototype: rejected because it weakens testability and makes DTO/view-state mixing likely.

Consequences:

- Initial delivery is fast and reviewable.
- Folder boundaries must be maintained manually.
- Future module extraction should be considered only after Core and Feature boundaries show real pressure.

Follow-ups:

- Add public profile API contract before implementing real other-user pages.
- Add upload contract before enabling photo upload.
- Add Kakao SDK only after explicit dependency approval.
- Revisit modularization after the first tested MVP loop.
