# NuguSauce Ops

This directory holds the deployment and GitOps configuration for NuguSauce.

Current deployment split:

- `ops/helm/nugusauce-api` deploys the backend API to Kubernetes.
- `ops/argocd` holds Argo CD `Application` manifests.
- `ops/image-updater` holds Argo CD Image Updater manifests.
- `ops/secrets` holds secret/config examples; production secrets should live here as `sops`-encrypted manifests.

Production domain:

- backend: `https://nugusauce.jaehyuns.com`

Runtime contract:

- backend `APP_URL` is the canonical public origin for CORS and generated links.
- iOS `NUGUSAUCE_API_BASE_URL` should point to `https://nugusauce.jaehyuns.com`.

Recommended flow:

1. Build and push the backend image from the app repo CI.
2. Argo CD syncs `ops/helm/nugusauce-api`.
3. Image Updater writes the promoted image tag back into `ops/helm/nugusauce-api/values.yaml`.
4. Prometheus scrapes the backend management port through the generated `ServiceMonitor`.

Notes:

- This chart is backend-only by design because the client is native iOS.
- The chart assumes the backend exposes actuator health and Prometheus endpoints on a dedicated management port.
- HTTPS can terminate outside the cluster when Cloudflare Tunnel is fronting the ingress.
