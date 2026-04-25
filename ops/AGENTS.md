# Ops Agent Guide

This file applies to local stack, deployment, environment, and smoke-check work under `ops/`.

## Required Context

- Product plan: `../.omx/plans/prd-nugusauce-v0.md`
- Test plan: `../.omx/plans/test-spec-nugusauce-v0.md`
- Local harness runbook: `../docs/runbooks/local-harness.md`
- Security: `../SECURITY.md`

## Ops Harness Rules

- Local stack work should make backend, Postgres, and Redis reproducible.
- Smoke checks must be scriptable or documented in `docs/runbooks/local-harness.md`.
- Do not commit real secrets or machine-specific credentials.
- Environment variables must have documented names and safe placeholders.
- Deployment or migration changes must include a rollback or recovery note.

## Expected Local Stack

The planned local stack is:

- backend API
- Postgres
- Redis
- health/smoke checks

Add concrete commands to `docs/runbooks/local-harness.md` when `ops/` gains executable assets.
