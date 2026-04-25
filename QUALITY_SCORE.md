# NuguSauce Quality Score

Use this as the completion gate for harness-oriented work. A change does not need every item, but it must cover the items it touches.

| Area | Required Evidence |
| --- | --- |
| Product intent | Linked to `.omx/plans/prd-nugusauce-v0.md` or a newer `.omx/plans/*` artifact |
| Test spec | Linked to `.omx/plans/test-spec-nugusauce-v0.md` or updated with a new acceptance criterion |
| Contract | API, error, or fixture changes reflected in `docs/contracts/` |
| Backend | Relevant Gradle tests pass or skipped with reason |
| iOS | ViewModel/unit/UI smoke plan exists when UI behavior changes |
| Ops | Local smoke check documented when runtime wiring changes |
| Security | Auth/JWT/PII changes checked against `SECURITY.md` |

## Minimum Done Bar

- New behavior is described by a contract, fixture, or scenario.
- At least one automated test or smoke check proves the changed behavior.
- Final report states what was verified and what was not verified.

## First Harness Targets

Keep the first implementation batch aligned with `.omx/plans/test-spec-nugusauce-v0.md`:

1. Famous recipe fixture draft
2. Kakao OIDC login integration baseline
3. Recipe create/review create application test
4. Recipe list/detail XCUITest smoke test
5. Docker Compose local stack
