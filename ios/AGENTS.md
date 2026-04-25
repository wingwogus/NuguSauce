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
- Fixtures: `../docs/contracts/fixtures.md`
- Security: `../SECURITY.md` for auth session, Keychain, Kakao, token, or PII changes

## iOS Harness Rules

- Keep networking decodable from `docs/contracts/api.md`.
- Use mock API data from `docs/contracts/fixtures.md` before relying on live backend behavior.
- Cover critical state transitions with unit tests before adding broad UI flow.
- Add XCUITest smoke coverage for the product flows named in `.omx/plans/test-spec-nugusauce-v0.md`.
- Do not introduce a new package or SDK without explicit user request.

## Auth Boundary

iOS obtains a Kakao OIDC ID token and sends it with a nonce to `POST /api/v1/auth/kakao/login`. Store NuguSauce service tokens in the platform-appropriate secure storage.
