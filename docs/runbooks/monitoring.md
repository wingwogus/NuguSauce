# Monitoring Runbook

NuguSauce uses Prometheus for aggregate service metrics, Grafana for dashboards and alerts, and Loki for individual request and product-event investigation.

## Dashboard

The Helm chart creates the `NuguSauce API & Product Funnel` dashboard as a ConfigMap labeled `grafana_dashboard=1`. A Grafana sidecar watching that label loads it automatically. Without a sidecar, copy the `nugusauce-api.json` value from the rendered ConfigMap and import it manually.

The dashboard covers the standard RED signals:

- request rate by normalized Spring MVC route
- 5xx ratio
- overall average/p95/p99 latency and per-route average/p95 latency
- JVM heap, process CPU, and HikariCP connection usage
- allowlisted product funnel event counts
- one-hour login and recipe-creation completion ratios for locating funnel drop-off
- recent structured 5xx logs from Loki

## Product event contract

`POST /api/v1/analytics/events` accepts only these event names:

- `screen_view`
- `search_submitted`
- `recipe_detail_view`
- `favorite_success`
- `recipe_create_start`
- `recipe_create_success`
- `login_start`
- `login_success`
- `login_failure`

The request schema intentionally has no free-form properties. Never add search text, review text, email, nickname, access tokens, refresh tokens, provider tokens, or nonce values. Session and recipe identifiers stay in structured logs and never become Prometheus labels. Prometheus exposes only the bounded `event_name` label.

## Loki retention check

Application pods continuously write request and event logs to standard output. Durable retention is owned by the cluster Loki configuration, not this repository. Confirm all of the following in the Loki runtime configuration:

```yaml
compactor:
  retention_enabled: true

limits_config:
  retention_period: 30d
```

Also verify that Promtail or Grafana Alloy discovers the `nugusauce` namespace and that Loki storage has enough capacity. Without a shipping agent, logs exist only in the Kubernetes container log and may disappear after pod or node log rotation.

The production Loki Helm values are versioned in `ops/observability/loki-values.yaml`. They pin the single-binary workload and its local-path volume to `k8s-master`, retain the PVC across StatefulSet scale/delete operations, and configure 30-day retention. The provisioned PV reclaim policy is patched to `Retain` after creation as documented in `ops/observability/README.md`.

Useful checks:

```text
{namespace="nugusauce"} | json | message = `http.request.completed`
{namespace="nugusauce"} | json | message = `analytics.event`
```

Cluster label names vary by the installed log shipper. Use Grafana Explore to inspect one NuguSauce log stream and update the dashboard Loki selector when the runtime uses labels other than `app`.

## Alert ownership

The chart installs three symptom-oriented alerts: sustained 5xx ratio above 5%, sustained overall p95 latency above one second, and a missing Prometheus target. Route alerts to an owned notification policy before enabling paging. Adjust thresholds only after observing normal production traffic for at least one week.
