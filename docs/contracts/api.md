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
    "profileImageUrl": null,
    "profileSetupRequired": true
  },
  "onboarding": {
    "status": "required",
    "requiredActions": [
      "accept_required_policies",
      "setup_profile"
    ]
  }
}
```

`member.email` is never returned from this endpoint. Kakao identity data proves
login only; the public NuguSauce nickname is a service profile field.

iOS must treat the returned token pair as pending login state until required
policy acceptance and required profile setup are complete. The token pair must
not be persisted as an authenticated app session before those gates pass.

`onboarding` describes the NuguSauce service onboarding state derived by the
backend from the current required policy versions and member profile state. It
is part of the API contract, not a UI route name.

- `onboarding.status = complete`: required consents and profile setup are
  complete; iOS may persist the returned token pair as the app session.
- `onboarding.status = required`: one or more service onboarding actions must be
  completed before iOS persists the app session.

Allowed `onboarding.requiredActions` values are:

- `accept_required_policies`: iOS must keep the token pair in pending memory,
  call `GET /api/v1/consents/status` with the pending access token, collect the
  missing required policy acceptances, and then continue remaining onboarding
  actions.
- `setup_profile`: iOS must collect the service nickname before persisting the
  session.

When both actions are required, the backend returns them in this order:

1. `accept_required_policies`
2. `setup_profile`

The login response intentionally does not include the full consent-status
payload. Clients fetch that detail only when `accept_required_policies` is
present or when a protected write fails with `CONSENT_001`.

### `POST /api/v1/auth/reissue`

Refresh token may come from the request body or `refreshToken` cookie.

Success data:

```json
{
  "accessToken": "<nugusauce_access_token>",
  "refreshToken": "<nugusauce_refresh_token>"
}
```

## Consent API

Kakao login proves identity only. It does not count as NuguSauce service-policy
acceptance until the backend records the current required policy versions for
that member.

Required policies are versioned by backend data:

- `terms_of_service`
- `privacy_policy`
- `content_policy`

When a required policy version changes, previously accepted older versions no
longer satisfy write/upload gates for that policy type.

### Consent enforcement

These endpoints require JWT and all current required consents:

- `POST /api/v1/media/images/upload-intent`
- `POST /api/v1/recipes`
- `PATCH /api/v1/me/recipes/{recipeId}`
- `DELETE /api/v1/me/recipes/{recipeId}`
- `POST /api/v1/recipes/{recipeId}/reviews`
- `POST /api/v1/recipes/{recipeId}/reports`
- `PATCH /api/v1/members/me` when `profileImageId` is supplied

These endpoints must remain usable without service-policy acceptance:

- Kakao login, token reissue, and logout
- `GET /api/v1/members/me`
- `GET /api/v1/consents/status`
- `POST /api/v1/consents/accept`
- Public read endpoints

Missing required consent fails with `CONSENT_001`.

### `GET /api/v1/consents/status`

Requires JWT.

Success data:

```json
{
  "policies": [
    {
      "policyType": "terms_of_service",
      "version": "2026-05-01",
      "title": "서비스 이용약관",
      "url": "nugusauce://legal/terms",
      "required": true,
      "accepted": false,
      "activeFrom": "2026-05-01T00:00:00Z"
    }
  ],
  "missingPolicies": [
    {
      "policyType": "terms_of_service",
      "version": "2026-05-01",
      "title": "서비스 이용약관",
      "url": "nugusauce://legal/terms",
      "required": true,
      "accepted": false,
      "activeFrom": "2026-05-01T00:00:00Z"
    }
  ],
  "requiredConsentsAccepted": false
}
```

`url` is an app-internal policy document reference, not a public backend web
page. iOS renders the policy body in-app from `policyType` and `version`; it
must not open `/legal/...` backend routes for consent.

### `POST /api/v1/consents/accept`

Requires JWT. The request must contain current required policy versions from
the status response. Stale versions fail with `COMMON_001`.

Request:

```json
{
  "acceptedPolicies": [
    { "policyType": "terms_of_service", "version": "2026-05-01" },
    { "policyType": "privacy_policy", "version": "2026-05-01" },
    { "policyType": "content_policy", "version": "2026-05-01" }
  ]
}
```

Success data matches the consent status shape.

## Member API

Member APIs use the shared response envelope above.

### Profile rules

- Member email and provider identity are never returned from member APIs.
- `nickname` is the service-owned public nickname.
- `displayName` is safe public display text. It is the nickname when set,
  otherwise `"사용자 {id}"`.
- `profileImageUrl` is a read-only display URL for the member's current profile
  image. It is null when the member has not set a profile image.
- `profileSetupRequired` is true when the member has no nickname.
- Nicknames are trimmed before validation and storage.
- Nicknames must be 2..20 characters and contain only Korean letters, English
  letters, digits, or `_`.
- Nicknames are globally unique.
- `profileImageId`, when supplied to the update endpoint, must be a verified
  media image owned by the authenticated member and not attached to another
  recipe or another member profile.

### `GET /api/v1/members/me`

Requires JWT.

Success data:

```json
{
  "id": 1,
  "nickname": "소스장인",
  "displayName": "소스장인",
  "profileImageUrl": "https://res.cloudinary.com/<cloud-name>/image/upload/f_auto,q_auto/nugusauce/images/1/<uuid>",
  "profileSetupRequired": false
}
```

### `PATCH /api/v1/members/me`

Requires JWT.

Request:

```json
{
  "nickname": "소스장인",
  "profileImageId": 50
}
```

Success data matches the `GET /api/v1/members/me` shape.

### `GET /api/v1/members/{memberId}`

Public endpoint for another member's safe public profile and profile-screen data.
Only visible authored recipes and visible favorite recipes are returned; hidden
recipes stay private to the owner. This public profile response is not
viewer-personalized; recipe summaries return `"isFavorite": false`.

Success data:

```json
{
  "id": 2,
  "nickname": "마라초보",
  "displayName": "마라초보",
  "profileImageUrl": "https://res.cloudinary.com/<cloud-name>/image/upload/f_auto,q_auto/nugusauce/images/2/<uuid>",
  "profileSetupRequired": false,
  "recipes": [
    {
      "id": 101,
      "title": "마늘 듬뿍 고소 소스",
      "description": "마늘 향이 강한 커스텀 조합",
      "imageUrl": null,
      "visibility": "VISIBLE",
      "ratingSummary": {
        "averageRating": 0.0,
        "reviewCount": 0
      },
      "tags": [
        { "id": 8, "name": "마늘향" },
        { "id": 1, "name": "고소함" }
      ],
      "favoriteCount": 2,
      "isFavorite": false,
      "createdAt": "2026-04-25T00:00:00Z"
    }
  ],
  "favoriteRecipes": [
    {
      "id": 1,
      "title": "건희 소스",
      "description": "고소하고 매콤한 인기 조합",
      "imageUrl": null,
      "visibility": "VISIBLE",
      "ratingSummary": {
        "averageRating": 4.7,
        "reviewCount": 12
      },
      "tags": [
        { "id": 2, "name": "매콤함" },
        { "id": 3, "name": "달달함" },
        { "id": 1, "name": "고소함" }
      ],
      "favoriteCount": 42,
      "isFavorite": false,
      "createdAt": "2026-04-25T00:00:00Z"
    }
  ]
}
```

## Media API

Media APIs use the shared response envelope above. Recipe and profile images
use direct client upload with a backend-owned media record:

1. iOS requests an upload intent from the backend.
2. iOS uploads the file directly to the returned Cloudinary signed target.
3. iOS calls complete so the backend verifies the provider asset.
4. iOS attaches the verified image through the recipe create request or member
   profile update request.

The client never receives or stores Cloudinary API secrets. Direct client
submission of arbitrary `imageUrl` values is not accepted for recipe creation
or profile updates. Read responses may expose `imageUrl` or `profileImageUrl`
as derived display URLs.

When a profile image is replaced, the backend keeps the new profile attachment
and detaches the previous profile image media during the member update. After
the update commits, it schedules provider deletion plus local media-record
cleanup for the old image. Recipe image creation has no replacement endpoint in
the current contract, so recipe image cleanup is not triggered by profile
changes.

### `POST /api/v1/media/images/upload-intent`

Requires JWT and all current required consents. iOS must show a photo/content
rights confirmation before requesting an upload intent.

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
      "public_id": "nugusauce/images/1/<uuid>",
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
  "imageUrl": "https://res.cloudinary.com/<cloud-name>/image/upload/f_auto,q_auto/nugusauce/images/1/<uuid>",
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

- `hot`: visible recipes ordered by recent review/favorite engagement velocity plus rating quality guard, then engagement score and recency fallback.
- `popular`: visible recipes ordered by engagement score (`reviewCount * 2 + favoriteCount`) descending, then `averageRating` descending, then newest review/creation.
- `recent`: visible recipes ordered by `createdAt` descending.
- `rating`: visible recipes ordered by `averageRating` descending, then `reviewCount` descending.

### `GET /api/v1/recipes`

Query parameters:

- `q`: optional keyword matched against title, description, and tips.
- `tagIds`: optional repeated or comma-compatible recipe taste tag IDs. Matching is based on source tags derived from the recipe's ingredient composition.
- `ingredientIds`: optional repeated or comma-compatible ingredient IDs.
- `sort`: optional `hot|popular|recent|rating`, default `popular`.

When a valid JWT is supplied, each summary is personalized with the current
member's favorite state. Anonymous public list requests return
`"isFavorite": false`. Any HTTP cache for this endpoint must vary by
authorization when personalized responses are enabled.
`favoriteCount` is the public aggregate number of members who saved the recipe
and is separate from viewer-relative `isFavorite`.
`tags` contains at most three recipe-owned taste tags derived from ingredient
ratio/amount composition; review text and rating never change these tags.

Success data:

```json
[
  {
    "id": 1,
    "title": "건희 소스",
    "description": "고소하고 매콤한 인기 조합",
    "imageUrl": null,
    "visibility": "VISIBLE",
    "ratingSummary": {
      "averageRating": 4.7,
      "reviewCount": 18
    },
    "tags": [
      { "id": 2, "name": "매콤함" },
      { "id": 3, "name": "달달함" },
      { "id": 1, "name": "고소함" }
    ],
    "favoriteCount": 42,
    "isFavorite": true,
    "createdAt": "2026-04-25T00:00:00Z"
  }
]
```

### `GET /api/v1/recipes/{recipeId}`

Publicly readable. When a valid JWT is supplied, the response is personalized
with the current member's favorite state; anonymous requests return
`"isFavorite": false`.
`favoriteCount` is public aggregate save count and does not depend on viewer
authentication.

Success data:

```json
{
  "id": 1,
  "title": "건희 소스",
  "description": "고소하고 매콤한 인기 조합",
  "imageUrl": null,
  "tips": "참기름은 마지막에 넣는다",
  "authorId": null,
  "authorName": "NuguSauce",
  "authorProfileImageUrl": null,
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
  "tags": [
    { "id": 2, "name": "매콤함" },
    { "id": 3, "name": "달달함" },
    { "id": 1, "name": "고소함" }
  ],
  "ratingSummary": {
    "averageRating": 4.7,
    "reviewCount": 18
  },
  "favoriteCount": 42,
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

`imageId` is optional. When present, it must refer to a verified media asset
owned by the authenticated member and not already attached to a recipe or
profile.
Legacy/direct `imageUrl` input is rejected with `COMMON_001`; recipe response
`imageUrl` remains a read-only display URL.

Recipe detail responses include `authorId`, the safe public member id for the
recipe author, and `authorName`, safe public display text for the recipe author.
They also include `authorProfileImageUrl`, the author's current profile image
display URL or null. Curated recipes use `"NuguSauce"` and `authorId: null`;
user recipes use the author's public member id, public nickname/display name,
and profile image URL when set.

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
`topping_seed`, `protein`, and `other`. Taste classification is derived from
recipe ingredient composition and exposed through recipe tags.

### `GET /api/v1/tags`

Success data:

```json
[
  { "id": 1, "name": "고소함" },
  { "id": 2, "name": "매콤함" },
  { "id": 3, "name": "달달함" },
  { "id": 4, "name": "상큼함" },
  { "id": 5, "name": "마라강함" },
  { "id": 6, "name": "감칠맛" },
  { "id": 7, "name": "담백함" },
  { "id": 8, "name": "마늘향" },
  { "id": 9, "name": "짭짤함" },
  { "id": 10, "name": "알싸함" },
  { "id": 11, "name": "향긋함" }
]
```

### `POST /api/v1/recipes/{recipeId}/reviews`

Requires JWT. A member may create only one active review per recipe in this MVP slice.

Request:

```json
{
  "rating": 5,
  "text": "고소하고 초보자도 먹기 좋았어요"
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
  "authorProfileImageUrl": "https://res.cloudinary.com/<cloud-name>/image/upload/f_auto,q_auto/nugusauce/images/7/<uuid>",
  "rating": 5,
  "text": "고소하고 초보자도 먹기 좋았어요",
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
    "authorProfileImageUrl": "https://res.cloudinary.com/<cloud-name>/image/upload/f_auto,q_auto/nugusauce/images/7/<uuid>",
    "rating": 5,
    "text": "고소하고 초보자도 먹기 좋았어요",
    "createdAt": "2026-04-25T01:00:00Z"
  }
]
```

`authorId` is the review author's safe public member id. `authorName` is safe
public display text for the review author. `authorProfileImageUrl` is the
author's current profile image display URL or null. Public review responses
must not expose the author's email address or provider identity.

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

Returns visible recipes authored by the authenticated member. Hidden recipes are
not returned from this tab. `isFavorite` is still viewer-relative, so authored
recipes may be either `true` or `false`.

Success data:

```json
[
  {
    "id": 101,
    "title": "마늘 듬뿍 고소 소스",
    "description": "마늘 향이 강한 커스텀 조합",
    "imageUrl": null,
    "visibility": "VISIBLE",
    "ratingSummary": {
      "averageRating": 0.0,
      "reviewCount": 0
    },
    "tags": [
      { "id": 8, "name": "마늘향" },
      { "id": 1, "name": "고소함" }
    ],
    "favoriteCount": 0,
    "isFavorite": false,
    "createdAt": "2026-04-25T00:00:00Z"
  }
]
```

### `PATCH /api/v1/me/recipes/{recipeId}`

Requires JWT and required service, privacy, and content/photo policy consents.

Updates a visible recipe authored by the authenticated member. The owner lookup
uses the authenticated member id and `recipeId`; missing recipes, curated
recipes, recipes owned by another member, and hidden update targets fail with
`RECIPE_001` so owner-only mutation endpoints do not disclose ownership.

Request:

```json
{
  "title": "수정한 내 소스",
  "description": "고소함을 더 살린 조합",
  "imageId": 51,
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

`imageId` is optional. When omitted, the existing recipe image is kept. When a
new `imageId` is supplied, it must be a verified media asset owned by the
authenticated member and not attached elsewhere. The previous local media asset
is detached from the recipe without deleting provider media.

Legacy/direct `imageUrl` input is rejected with `COMMON_001`.

Success data matches the recipe detail shape.

### `DELETE /api/v1/me/recipes/{recipeId}`

Requires JWT and required service, privacy, and content/photo policy consents.

Permanently deletes an authenticated member's own recipe. The backend removes
the recipe row and owned recipe graph including ingredient rows, reviews, review
tag links, favorites, reports, and recipe tag links. Local media metadata is
detached from the recipe; provider media is not deleted by this endpoint.

Missing recipes, curated recipes, and recipes owned by another member fail with
`RECIPE_001`. Repeating the delete after the row has already been removed also
fails with `RECIPE_001`.

Success data is empty:

```json
{
  "success": true,
  "data": null,
  "error": null
}
```

After deletion, public search, public detail, favorite lists, public profile
recipe lists, and `GET /api/v1/me/recipes` must not expose the deleted recipe.

### `GET /api/v1/me/favorite-recipes`

Returns visible recipes saved by the authenticated member. Hidden favorites are
excluded from this public-consumption list. Every returned recipe summary has
`"isFavorite": true`.

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
