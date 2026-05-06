# Error Contracts

All public API errors must fit the shared response envelope:

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

## Rules

- `code` is stable enough for iOS branching.
- `message` is user-facing or localization-key compatible.
- `detail` is optional and must not leak secrets, token values, stack traces, or private user data.
- Validation errors should keep a predictable field-level shape in `detail`.

## Current Stable Codes

Common:

- `COMMON_001`: invalid input
- `COMMON_002`: invalid JSON
- `COMMON_999`: internal error
- `RESOURCE_001`: resource not found

Consent:

- `CONSENT_001`: required service, privacy, or content/photo policy consent is missing

Auth/user:

- `AUTH_001`: unauthorized
- `AUTH_002`: forbidden
- `AUTH_003`: duplicate email
- `AUTH_004`: email not verified
- `AUTH_005`: auth code not found
- `AUTH_006`: auth code mismatch
- `AUTH_007`: already logged out
- `AUTH_008`: malformed JWT
- `AUTH_009`: invalid Kakao token
- `AUTH_010`: Kakao nonce mismatch
- `AUTH_011`: Kakao nonce replay
- `AUTH_012`: Kakao verified email required
- `AUTH_013`: social-only member local login forbidden
- `USER_001`: user not found
- `USER_002`: user already exists
- `USER_003`: invalid nickname
- `USER_004`: duplicate nickname

Recipe MVP:

- `RECIPE_001`: recipe not found
- `RECIPE_002`: hidden recipe cannot be read from public surfaces
- `RECIPE_003`: ingredient not found
- `RECIPE_004`: tag not found
- `RECIPE_005`: duplicate review
- `RECIPE_006`: duplicate report
- `RECIPE_007`: invalid rating
- `RECIPE_008`: invalid ingredient amount or ratio
- `RECIPE_009`: forbidden admin action
- `RECIPE_010`: duplicate favorite
- `RECIPE_011`: favorite not found

Media:

- `MEDIA_001`: media asset not found
- `MEDIA_002`: unsupported media content type
- `MEDIA_003`: media file too large
- `MEDIA_004`: media upload has not been verified
- `MEDIA_005`: media asset belongs to another member
- `MEDIA_006`: media asset already attached to a recipe or profile
- `MEDIA_007`: media provider unavailable or not configured
- `MEDIA_008`: uploaded provider asset not found

## Harness Requirement

When an error shape changes:

- Update this document.
- Add or update backend controller/API tests.
- Update iOS decoding expectations when the iOS client exists.
