# iOS Agent Guide

This file applies to future iOS work under `ios/`.

## Expected Stack

- SwiftUI app
- Xcode project
- Unit tests for state and view models
- XCUITest for smoke scenarios

## Required Context

- Product plan: `../.omx/plans/prd-nugusauce-v0.md`
- Test plan: `../.omx/plans/test-spec-nugusauce-v0.md`
- Design system: `DESIGN.md` for iOS/front-end UI and visual design work
- API contracts: `../docs/contracts/api.md`
- Error shape: `../docs/contracts/errors.md`
- Fixtures: `../docs/contracts/fixtures.md` for backend test and seed semantics only
- Security: `../SECURITY.md` for auth session, Keychain, Kakao, token, or PII changes

## iOS Harness Rules

- Keep networking decodable from `docs/contracts/api.md`.
- iOS runtime must use the live backend through `BackendAPIClient`; do not add fixture-backed or mock-backed app data loaders.
- Test-only doubles may exist in `NuguSauceTests`, but they must not be linked into the app target or used as product data.
- Cover critical state transitions with unit tests before adding broad UI flow.
- Add XCUITest smoke coverage for the product flows named in `.omx/plans/test-spec-nugusauce-v0.md`.
- Do not introduce a new package or SDK without explicit user request.

## Commit Convention

- Follow the repository root commit convention for iOS changes.
- Use the root `<type>: {변경사항 한국어 동작 구문}` format and choose the type by the actual iOS change.
- Keep the Korean subject after `<type>:` short, but include an action word when it makes the change clearer; do not use sentence endings such as `~한다`.

## Auth Boundary

iOS obtains a Kakao OIDC ID token and sends it with a nonce to `POST /api/v1/auth/kakao/login`. Store NuguSauce service tokens in the platform-appropriate secure storage.
