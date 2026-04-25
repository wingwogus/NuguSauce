# Local Harness Runbook

This runbook is for executing the local harness, not for storing design rationale.

## Backend Test Harness

From `backend/`:

```bash
./gradlew test
```

Focused checks:

```bash
./gradlew :application:test
./gradlew :api:test
```

## Backend Runtime Smoke

From `backend/`:

```bash
./gradlew :api:bootRun
```

Seeded local runtime from `backend/`:

```bash
NUGUSAUCE_SEED_ENABLED=true ./gradlew :api:bootRun --args='--spring.profiles.active=local'
```

The local seed is disabled by default. When enabled, it inserts deterministic members,
ingredients, tags, recipes, reviews, reports, and favorites from the fixture contract
shape if the baseline user is absent.

iOS must still connect to the backend HTTP API for these records. Do not point the app
at bundled fixture JSON or an in-app mock client; seed data becomes app-visible only
after the backend persists and serves it.

Expected smoke targets once runtime wiring is active:

- `/actuator/health`
- auth token exchange baseline
- recipe list API
- my recipe and favorite recipe APIs with a local test token

## Full Local Stack

`ops/` and `docker-compose` are not present yet. When added, this runbook should define:

- backend service
- Postgres
- Redis
- migration check
- smoke check command

## Completion Report

Every harness run should report:

- command executed
- pass/fail result
- skipped checks and reason
- known residual risk
