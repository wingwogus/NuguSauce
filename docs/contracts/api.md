# API Contracts

This document is the shared API contract surface for backend and iOS work.

## Client Data Loading Rule

iOS app runtime must load product data only from these backend endpoints. Do not
ship fixture-backed, mock-backed, or hard-coded recipe/ingredient/tag/review/profile
records in the app target. Test-only doubles may validate decoding and request
composition, but production screens must be backed by HTTP responses.

## Backend Contract Shape

Backend code keeps transport DTOs separate from application use-case models.

### API module

The `api` module owns HTTP-facing request and response DTOs:

- Controllers and transport DTOs are grouped by feature package in the Tribe project style.
- Example feature package: `com.nugusauce.api.auth` contains `AuthController`, `AuthRequests`, and `AuthResponses`.
- Example feature package: `com.nugusauce.api.recipe` contains `RecipeController`, `AdminRecipeController`, `RecipeRequests`, and `RecipeResponses`.
- New feature APIs should not split controller and DTO code into generic `api/controller` and `api/dto` trees.
- Request DTOs live under `*Requests`.
- Response DTOs live under `*Responses`.
- Controllers map request DTOs into application commands.
- Controllers map application results into response DTOs.
- API DTOs may contain validation annotations and HTTP/client-facing field names.

Example:

```text
AuthRequests.KakaoLoginRequest
AuthResponses.TokenResponse
```

### Application module

The `application` module owns use-case input and output models:

- Use-case input models live under `*Command`.
- Use-case output models live under `*Result`.
- Application models must not depend on HTTP annotations, controller types, cookies, or servlet APIs.
- Services should accept commands and return results instead of API DTOs.

Example:

```text
AuthCommand.KakaoLogin
AuthResult.TokenPair
```

This separation is part of the harness contract: API tests assert transport behavior, while application tests assert use-case behavior without HTTP coupling.

### Class separation rule

Default to keeping closely related backend types together. Do not split every request, response, command, result, mapper, or helper into its own file by habit.

Prefer grouped objects and local private helpers when the types share one feature boundary and one reason to change. Split into separate classes/files only when there is a concrete pressure:

- The type has an independent lifecycle or is reused across multiple feature boundaries.
- The file mixes unrelated use cases or domains.
- Tests, reviews, or diffs become hard to read because the file is genuinely large or complex.
- A helper needs its own injected dependencies or public contract.
- Keeping it together would create circular dependencies or unclear ownership.

When splitting, name the new boundary after the responsibility, not after a generic pattern.

## Response Envelope

Current backend responses use:

```json
{
  "success": true,
  "data": {},
  "error": null
}
```

Failure responses use:

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "ERROR_CODE",
    "message": "message.key.or.localized.message",
    "detail": null
  }
}
```

The Kotlin source of truth is `backend/api/src/main/kotlin/com/nugusauce/api/common/ApiResponse.kt`.

## Auth Endpoints

### `POST /api/v1/auth/kakao/login`

Request:

```json
{
  "idToken": "<kakao_oidc_id_token>",
  "nonce": "<client_generated_nonce>",
  "kakaoAccessToken": "<kakao_oauth_access_token>"
}
```

Backend verifies the ID token signature, issuer, audience, timestamps, and nonce,
then calls Kakao OIDC userinfo with `kakaoAccessToken` to confirm `sub` matches
and `email_verified` is true before linking or creating a local member. iOS must
request `openid` and `account_email` scopes so the access token can read the
verified email claim.

Success data:

```json
{
  "accessToken": "<nugusauce_access_token>",
  "refreshToken": "<nugusauce_refresh_token>"
}
```

### `POST /api/v1/auth/reissue`

Refresh token may come from the request body or `refreshToken` cookie.

Success data matches the token pair shape above.

## Recipe API

Recipe APIs use the shared response envelope above.

### Visibility and auth rules

- Public recipe reads only return recipes with `visibility = "VISIBLE"`.
- Hidden recipes are excluded from public lists and detail responses.
- Recipe creation, review creation, report creation, and admin visibility changes require JWT authentication.
- Admin routes require `ROLE_ADMIN`.
- Public recipe and review responses must not expose reporter identity or user email.

### Sort semantics

Recipe list supports `sort` values:

- `popular`: visible recipes ordered by `reviewCount` descending, then `averageRating` descending, then newest review/creation.
- `recent`: visible recipes ordered by `createdAt` descending.
- `rating`: visible recipes ordered by `averageRating` descending, then `reviewCount` descending.

### `GET /api/v1/recipes`

Query parameters:

- `q`: optional keyword matched against title, description, and tips.
- `tagIds`: optional repeated or comma-compatible review taste tag IDs. Matching is based on tags selected in reviews, not author input.
- `ingredientIds`: optional repeated or comma-compatible ingredient IDs.
- `sort`: optional `popular|recent|rating`, default `popular`.

Success data:

```json
[
  {
    "id": 1,
    "title": "건희 소스",
    "description": "고소하고 매콤한 인기 조합",
    "imageUrl": null,
    "authorType": "CURATED",
    "visibility": "VISIBLE",
    "ratingSummary": {
      "averageRating": 4.7,
      "reviewCount": 18
    },
    "reviewTags": [
      { "id": 1, "name": "고소함", "count": 12 },
      { "id": 2, "name": "매콤함", "count": 6 }
    ],
    "createdAt": "2026-04-25T00:00:00Z"
  }
]
```

### `GET /api/v1/recipes/{recipeId}`

Success data:

```json
{
  "id": 1,
  "title": "건희 소스",
  "description": "고소하고 매콤한 인기 조합",
  "imageUrl": null,
  "tips": "참기름은 마지막에 넣는다",
  "authorType": "CURATED",
  "visibility": "VISIBLE",
  "ingredients": [
    {
      "ingredientId": 1,
      "name": "참기름",
      "amount": 1.0,
      "unit": "스푼",
      "ratio": null
    }
  ],
  "reviewTags": [
    { "id": 1, "name": "고소함", "count": 12 },
    { "id": 2, "name": "매콤함", "count": 6 }
  ],
  "ratingSummary": {
    "averageRating": 4.7,
    "reviewCount": 18
  },
  "createdAt": "2026-04-25T00:00:00Z",
  "lastReviewedAt": "2026-04-25T01:00:00Z"
}
```

### `POST /api/v1/recipes`

Requires JWT.

Request:

```json
{
  "title": "내 소스",
  "description": "고소하고 살짝 매운 조합",
  "imageUrl": null,
  "tips": "땅콩소스를 먼저 푼다",
  "ingredients": [
    {
      "ingredientId": 1,
      "amount": 1.0,
      "unit": "스푼",
      "ratio": null
    }
  ]
}
```

Authors can only submit the sauce composition and optional text/media fields. `spiceLevel`, `richnessLevel`, and `tagIds` are not accepted on user-created recipes; taste classification comes from reviews. Requests containing author-selected taste classification fields fail with `COMMON_001`.

Success status: `201 Created`

Success data matches the recipe detail shape.

### `GET /api/v1/ingredients`

Success data:

```json
[
  { "id": 1, "name": "참기름", "category": "oil" }
]
```

### `GET /api/v1/tags`

Success data:

```json
[
  { "id": 1, "name": "고소함" }
]
```

### `POST /api/v1/recipes/{recipeId}/reviews`

Requires JWT. A member may create only one active review per recipe in this MVP slice.

Request:

```json
{
  "rating": 5,
  "text": "고소하고 초보자도 먹기 좋았어요",
  "tasteTagIds": [1, 2]
}
```

Success status: `201 Created`

Success data:

```json
{
  "id": 10,
  "recipeId": 1,
  "rating": 5,
  "text": "고소하고 초보자도 먹기 좋았어요",
  "tasteTags": [
    { "id": 1, "name": "고소함" }
  ],
  "createdAt": "2026-04-25T01:00:00Z"
}
```

### `GET /api/v1/recipes/{recipeId}/reviews`

Success data:

```json
[
  {
    "id": 10,
    "recipeId": 1,
    "rating": 5,
    "text": "고소하고 초보자도 먹기 좋았어요",
    "tasteTags": [
      { "id": 1, "name": "고소함" }
    ],
    "createdAt": "2026-04-25T01:00:00Z"
  }
]
```

### `POST /api/v1/recipes/{recipeId}/reports`

Requires JWT. Reporter identity is never included in public responses.

Request:

```json
{
  "reason": "부적절한 내용"
}
```

Success status: `201 Created`

Success data:

```json
{
  "id": 20,
  "recipeId": 1,
  "reason": "부적절한 내용",
  "createdAt": "2026-04-25T01:30:00Z"
}
```

### `PATCH /api/v1/admin/recipes/{recipeId}/visibility`

Requires `ROLE_ADMIN`.

Request:

```json
{
  "visibility": "HIDDEN"
}
```

Success data matches the recipe detail shape.

## My Recipe APIs

My recipe APIs require JWT authentication and never expose another user's private profile data.

### `GET /api/v1/me/recipes`

Returns recipes authored by the authenticated member. Hidden own recipes may be returned so the author can manage them.

Success data:

```json
[
  {
    "id": 101,
    "title": "마늘 듬뿍 고소 소스",
    "description": "마늘 향이 강한 사용자 조합",
    "imageUrl": null,
    "authorType": "USER",
    "visibility": "VISIBLE",
    "ratingSummary": {
      "averageRating": 0.0,
      "reviewCount": 0
    },
    "reviewTags": [],
    "createdAt": "2026-04-25T00:00:00Z"
  }
]
```

### `GET /api/v1/me/favorite-recipes`

Returns visible recipes saved by the authenticated member. Hidden favorites are excluded from this public-consumption list.

Success data matches the recipe summary list shape.

### `POST /api/v1/me/favorite-recipes/{recipeId}`

Requires JWT. Hidden recipes cannot be favorited.

Success status: `201 Created`

Success data:

```json
{
  "recipeId": 1,
  "createdAt": "2026-04-25T02:00:00Z"
}
```

Duplicate favorites fail with `RECIPE_010`.

### `DELETE /api/v1/me/favorite-recipes/{recipeId}`

Requires JWT.

Success data is empty:

```json
{
  "success": true,
  "data": null,
  "error": null
}
```

Deleting a non-existing favorite fails with `RECIPE_011`.
