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

Recipe image upload requires Cloudinary credentials. `cloud_name` is non-secret
and currently defaults to `dyzg8xb4n`; the API key and secret must be supplied
from the Cloudinary dashboard:

```bash
export CLOUDINARY_CLOUD_NAME=dyzg8xb4n
export CLOUDINARY_API_KEY=<cloudinary-api-key>
export CLOUDINARY_API_SECRET=<cloudinary-api-secret>
./gradlew :api:bootRun --args='--spring.profiles.active=local'
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

Deployment assets now mirror the Tribe backend GitOps setup:

- backend image: `docker.io/vantagac/nugusauce-api`
- Helm chart: `ops/helm/nugusauce-api`
- Argo CD app: `ops/argocd/nugusauce-api-prod.yaml`
- Image Updater: `ops/image-updater/nugusauce-api-updater.yaml`
- production API origin: `https://nugusauce.jaehyuns.com`

Local `docker-compose` is still not present. When added, it should provide:

- backend service
- Postgres
- Redis
- migration check
- smoke check command

Production smoke targets after deployment:

```bash
curl -fsS https://nugusauce.jaehyuns.com/actuator/health
curl -fsS https://nugusauce.jaehyuns.com/api/v1/recipes
```

## Completion Report

Every harness run should report:

- command executed
- pass/fail result
- skipped checks and reason
- known residual risk
