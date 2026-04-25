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

- Commit subjects must always use `feat:{변경사항 한국어로}`.
- Write the text after `feat:` in Korean and summarize the actual committed change.

## Boundaries

- Prefer small, reversible changes.
- No new production dependencies without explicit user request.
- Keep backend, iOS, and ops rules separate; keep shared contracts in `docs/contracts/`.
- Do not read every document by default. Follow the route for the current task.
