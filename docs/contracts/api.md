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
  "refreshToken": "<nugusauce_refresh_token>",
  "member": {
    "id": 1,
    "nickname": null,
    "displayName": "사용자 1",
    "profileSetupRequired": true
  }
}
```

`member.email` is never returned from this endpoint. Kakao identity data proves
login only; the public NuguSauce nickname is a service profile field.

### `POST /api/v1/auth/reissue`

Refresh token may come from the request body or `refreshToken` cookie.

Success data:

```json
{
  "accessToken": "<nugusauce_access_token>",
  "refreshToken": "<nugusauce_refresh_token>"
}
```

## Member API

Member APIs use the shared response envelope above.

### Profile rules

- Member email and provider identity are never returned from member APIs.
- `nickname` is the service-owned public nickname.
- `displayName` is safe public display text. It is the nickname when set,
  otherwise `"사용자 {id}"`.
- `profileSetupRequired` is true when the member has no nickname.
- Nicknames are trimmed before validation and storage.
- Nicknames must be 2..20 characters and contain only Korean letters, English
  letters, digits, or `_`.
- Nicknames are globally unique.

### `GET /api/v1/members/me`

Requires JWT.

Success data:

```json
{
  "id": 1,
  "nickname": "소스장인",
  "displayName": "소스장인",
  "profileSetupRequired": false
}
```

### `PATCH /api/v1/members/me`

Requires JWT.

Request:

```json
{
  "nickname": "소스장인"
}
```

Success data matches the `GET /api/v1/members/me` shape.

### `GET /api/v1/members/{memberId}`

Public endpoint for another member's safe public profile and profile-screen data.
Only visible authored recipes and visible favorite recipes are returned; hidden
recipes stay private to the owner.

Success data:

```json
{
  "id": 2,
  "nickname": "마라초보",
  "displayName": "마라초보",
  "profileSetupRequired": false,
  "recipes": [
    {
      "id": 101,
      "title": "마늘 듬뿍 고소 소스",
      "description": "마늘 향이 강한 커스텀 조합",
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
  ],
  "favoriteRecipes": [
    {
      "id": 1,
      "title": "건희 소스",
      "description": "고소하고 매콤한 인기 조합",
      "imageUrl": null,
      "authorType": "CURATED",
      "visibility": "VISIBLE",
      "ratingSummary": {
        "averageRating": 4.7,
        "reviewCount": 12
      },
      "reviewTags": [],
      "createdAt": "2026-04-25T00:00:00Z"
    }
  ]
}
```

## Media API

Media APIs use the shared response envelope above. Recipe images use direct
client upload with a backend-owned media record:

1. iOS requests an upload intent from the backend.
2. iOS uploads the file directly to the returned Cloudinary signed target.
3. iOS calls complete so the backend verifies the provider asset.
4. iOS creates the recipe with `imageId`.

The client never receives or stores Cloudinary API secrets. Direct client
submission of arbitrary `imageUrl` values is not accepted for recipe creation.
Recipe read responses may still expose `imageUrl` as a derived display URL.

### `POST /api/v1/media/images/upload-intent`

Requires JWT.

Request:

```json
{
  "contentType": "image/jpeg",
  "byteSize": 2048000,
  "fileExtension": "jpg"
}
```

Supported content types are `image/jpeg`, `image/png`, `image/heic`, and
`image/heif`. Current max image size is 5 MiB.

Success status: `201 Created`

Success data:

```json
{
  "imageId": 50,
  "upload": {
    "url": "https://api.cloudinary.com/v1_1/<cloud-name>/image/upload",
    "method": "POST",
    "headers": {},
    "fields": {
      "api_key": "<public-api-key>",
      "public_id": "nugusauce/recipes/1/<uuid>",
      "timestamp": "1777399200",
      "overwrite": "false",
      "signature": "<server-generated-signature>"
    },
    "fileField": "file",
    "expiresAt": "2026-04-28T14:30:00Z"
  },
  "constraints": {
    "maxBytes": 5242880,
    "allowedContentTypes": ["image/jpeg", "image/png", "image/heic", "image/heif"]
  }
}
```

### `POST /api/v1/media/images/{imageId}/complete`

Requires JWT. The image must belong to the authenticated member. The backend
checks the provider asset before marking the media record verified.

Success data:

```json
{
  "imageId": 50,
  "imageUrl": "https://res.cloudinary.com/<cloud-name>/image/upload/f_auto,q_auto/nugusauce/recipes/1/<uuid>",
  "width": 800,
  "height": 600
}
```

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

Publicly readable. When a valid JWT is supplied, the response is personalized
with the current member's favorite state; anonymous requests return
`"isFavorite": false`.

Success data:

```json
{
  "id": 1,
  "title": "건희 소스",
  "description": "고소하고 매콤한 인기 조합",
  "imageUrl": null,
  "tips": "참기름은 마지막에 넣는다",
  "authorType": "CURATED",
  "authorId": null,
  "authorName": "NuguSauce",
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
  "isFavorite": true,
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
  "imageId": 50,
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

Authors can only submit the sauce composition and optional media fields. `spiceLevel`, `richnessLevel`, and `tagIds` are not accepted on user-created recipes; taste classification comes from reviews. Requests containing author-selected taste classification fields fail with `COMMON_001`.

`imageId` is optional. When present, it must refer to a verified media asset
owned by the authenticated member and not already attached to another recipe.
Legacy/direct `imageUrl` input is rejected with `COMMON_001`; recipe response
`imageUrl` remains a read-only display URL.

Recipe detail responses include `authorId`, the safe public member id for the
recipe author, and `authorName`, safe public display text for the recipe author.
Curated recipes use `"NuguSauce"` and `authorId: null`; user recipes use the
author's public member id and public nickname/display name.

Success status: `201 Created`

Success data matches the recipe detail shape.

### `GET /api/v1/ingredients`

Success data:

```json
[
  { "id": 1, "name": "참기름", "category": "oil" },
  { "id": 2, "name": "땅콩소스", "category": "sauce_paste" }
]
```

Ingredient `category` is a physical ingredient grouping for sauce registration,
not a taste classification. Current stable category values are `sauce_paste`,
`oil`, `vinegar_citrus`, `fresh_aromatic`, `dry_seasoning`, `sweet_dairy`,
`topping_seed`, `protein`, and `other`. Taste classification remains in
review/tag data.

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
  "authorId": 7,
  "authorName": "소스장인",
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
    "authorId": 7,
    "authorName": "소스장인",
    "rating": 5,
    "text": "고소하고 초보자도 먹기 좋았어요",
    "tasteTags": [
      { "id": 1, "name": "고소함" }
    ],
    "createdAt": "2026-04-25T01:00:00Z"
  }
]
```

`authorId` is the review author's safe public member id. `authorName` is safe
public display text for the review author. Public review responses must not
expose the author's email address or provider identity.

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
    "description": "마늘 향이 강한 커스텀 조합",
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
