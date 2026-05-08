# NuguSauce Agent Map

This file is a routing map, not the full knowledge base. Keep it short.

## Canonical Sources

- Product and execution plans live in `.omx/plans/`.
- Detailed project knowledge lives in `docs/`.
- Runtime state, interviews, and generated OMX artifacts stay under `.omx/`.
- Do not move `.omx/plans/*` into `docs/` unless the user explicitly changes the source-of-truth policy.

## Always Check Before Substantive Changes

Read only what is relevant for the task:

- Product intent: `.omx/plans/prd-nugusauce-v0.md`
- Verification intent: `.omx/plans/test-spec-nugusauce-v0.md`
- System boundaries: `ARCHITECTURE.md`
- Quality gate: `QUALITY_SCORE.md`
- Security-sensitive work: `SECURITY.md`

## Task Routing

- Backend work: read `backend/AGENTS.md`.
- iOS work: read `ios/AGENTS.md`.
- Ops or local stack work: read `ops/AGENTS.md`.
- API shape changes: read `docs/contracts/api.md` and `docs/contracts/errors.md`.
- Fixture or seed data changes: read `docs/contracts/fixtures.md`.
- Local harness or smoke work: read `docs/runbooks/local-harness.md`.
- Auth, token, Kakao, JWT, or PII work: read `SECURITY.md`.

Nested `AGENTS.md` files are strongest when Codex is started from that directory. If the session starts at repo root and touches `backend/`, `ios/`, or `ops/`, explicitly read that directory's `AGENTS.md` first.

## Harness Rule

Harness engineering means contract, fixture, scenario, and automated verification come before feature expansion.

A feature is not done unless at least one requirement is locked by an automated check or a documented manual smoke check. If verification is skipped, report the reason and residual risk.

## Commit Convention

- Commit subjects must use `<type>: {변경사항 한국어 동작 구문}`.
- Allowed types:
  - `feat`: 새로운 기능 추가
  - `fix`: 버그 수정
  - `docs`: 문서 수정
  - `refactor`: 기능 변경 없는 코드 리팩토링
  - `test`: 테스트 코드 추가 또는 수정
  - `chore`: 빌드, 패키지 매니저 설정 등 기타 잡일
- Choose the type by the actual committed change. Do not force `feat` for fixes, docs, tests, refactors, or chores.
- Write the text after `<type>:` in Korean and summarize the actual committed change.
- Keep commit subjects short, but include an action word when it makes the change clearer, e.g. `백엔드 커밋 타입 규칙 수정`.
- Do not use full sentence endings such as `~한다`; prefer concise action phrases ending in words such as `추가`, `수정`, `적용`, `정리`, `검증`, or `지원`.

## Boundaries

- Prefer small, reversible changes.
- No new production dependencies without explicit user request.
- Keep backend, iOS, and ops rules separate; keep shared contracts in `docs/contracts/`.
- Do not read every document by default. Follow the route for the current task.
