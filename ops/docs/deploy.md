# Deployment Notes

This repository uses the same backend GitOps shape as the Tribe project.

Current target topology:

- `backend/` -> Kubernetes via `ops/helm/nugusauce-api` (`https://nugusauce.jaehyuns.com`)
- `ios/` -> native iOS client configured with `NUGUSAUCE_API_BASE_URL`

Required backend prerequisites before production rollout:

- build the backend API jar with `./gradlew --no-daemon clean :api:bootJar`
- apply `ops/docs/consent-rollout.sql` to the target PostgreSQL database before deploying any backend image that enforces `CONSENT_001`
- apply `ops/sql/external-identity-apple-provider.sql` before deploying any backend image that writes Apple `external_identity` rows
- build and push `docker.io/vantagac/nugusauce-api:<git-sha>`
- expose actuator health and Prometheus endpoints on management port `9090`
- allow actuator health and Prometheus routes through Spring Security
- configure forwarded headers for reverse proxy operation

Recommended ingress behavior:

- host: `nugusauce.jaehyuns.com`
- sticky session cookie name: `nugusauce-api-route`
- extended read/send timeouts for long-running requests
- TLS termination can stay outside the cluster when Cloudflare Tunnel or another external proxy handles HTTPS

Required runtime configuration:

- backend `APP_URL` should point to the canonical public origin: `https://nugusauce.jaehyuns.com`
- iOS `NUGUSAUCE_API_BASE_URL` should point to `https://nugusauce.jaehyuns.com`

External platform changes:

- Cloudflare Tunnel/DNS: route `nugusauce.jaehyuns.com` to the existing ingress/LB target.
- Kakao native app settings: register the iOS bundle ID and keep the backend OIDC audience equal to `KAKAO_NATIVE_APP_KEY`.
- Apple Sign in settings: keep the backend OIDC audience equal to `APPLE_CLIENT_ID`, currently the iOS client id `com.nugusauce.ios`.

Argo CD source path:

- repo: `https://github.com/wingwogus/NuguSauce.git`
- path: `ops/helm/nugusauce-api`

Image Updater write-back path:

- `ops/helm/nugusauce-api/values.yaml`

Image Updater notes:

- Only the backend image is updater-managed because the client is native iOS.
- The updater writes back into this same monorepo, relative to the Argo CD app source path.
- Expected write-back target:
  - `image.repository`
  - `image.tag`
- Expected tag shape:
  - commit SHA tags only
  - `latest` is ignored
- If the registry is private, configure registry credentials for Argo CD Image Updater in `argocd`.
- Git write-back requires a `git-creds` secret in the `argocd` namespace.

Rollback / recovery:

- Roll back the API by setting `ops/helm/nugusauce-api/values.yaml` `image.tag` to the previous known-good commit SHA and syncing the Argo CD application.
- If a config or secret rollout fails, re-apply the previous encrypted `nugusauce-api-config.enc.yaml` or `nugusauce-api-secret.enc.yaml` with `sops --decrypt ... | kubectl apply -n nugusauce -f -`.
