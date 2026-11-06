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

## User counts

The top row shows total social users, users with a retained login session, and
Apple/Kakao account counts. The user trend panel records changes from the first
deployment of these metrics; it cannot reconstruct historical account counts.

| Metric | Meaning |
| --- | --- |
| `nugusauce_users_registered` | Distinct members linked to at least one external identity; excludes local-only and seed accounts |
| `nugusauce_users_registered_by_provider{provider="APPLE"\|"KAKAO"}` | Distinct members linked to each provider; a member linked to both is counted in each provider but once in the total |
| `nugusauce_users_logged_in` | Distinct social members with an unexpired `refresh:<memberId>` key in the app's configured Redis database |
| `nugusauce_users_metrics_last_success_timestamp_seconds` | Unix timestamp of the last complete successful collection |

“로그인 유지 중인 사용자” means retained refresh sessions, **not concurrent online
users**. Refresh tokens currently expire after 14 days and are renewed on token
reissue. A session can outlive the user's last app visit. Measuring people using
the app now would require separate activity or heartbeat tracking.

Counts are collected in the background every 60 seconds; Prometheus scrapes and
Grafana refreshes every 30 seconds. Scrapes read the cached aggregate and never
query PostgreSQL or Redis. No email, nickname, member ID, or token value is exposed
as a metric or label. Redis keys are deduplicated and checked against social
members in NuguSauce's database; keys without a matching social member are discarded.
Each scan is capped at 10,000 returned keys, including duplicates, and database
session lookups use batches of 500 IDs. Exceeding the scan limit fails the
collection rather than publishing a truncated count; review this bound if the
number of retained sessions approaches 10,000.

Dashboard queries use `max` across API replicas instead of adding identical
global counts. They discard samples whose last successful collection is at least
180 seconds old. The stat panels use instant queries so old values in the selected
time range cannot masquerade as current counts. An initial or stale collection
shows no data (`수집 대기/지연`), not zero. Collection failures preserve the last
complete snapshot and retry on the next scheduled run.

### Verify and recover

Validate replica deduplication, stale-data suppression, real zero counts, and
missing data with Prometheus's `promtool`:

```bash
helm lint ops/helm/nugusauce-api
promtool test rules ops/tests/users.promql.test.yaml
```

After deployment, check the management endpoint inside the cluster:

```bash
kubectl get --raw '/api/v1/namespaces/nugusauce/services/http:nugusauce-api:9090/proxy/actuator/prometheus' \
  | rg '^nugusauce_users_'
```

In Grafana Explore, run `nugusauce_users_registered{namespace="nugusauce"}` and
`nugusauce_users_logged_in{namespace="nugusauce"}`, then compare with an aggregate
read-only DB/session query. Verify that logout or expiry reduces the session count
after the next collection. Do not log token values or list user identities.

If panels show no data, inspect the freshness gauge, the API's user-metrics
collection warning, Redis connectivity, and the ServiceMonitor target. Do not
replace missing data with zero or widen Redis scanning to unrelated key prefixes.
To roll back, restore the previous immutable API image tag and dashboard template
in Git and let Argo CD sync, following `ops/docs/deploy.md`. No schema migration or
auth data change is required.

Grafana's [Prometheus query editor](https://grafana.com/docs/grafana/latest/datasources/prometheus/query-editor/)
documents instant queries; Prometheus documents the aggregation and freshness
matching in its [query operators](https://prometheus.io/docs/prometheus/latest/querying/operators/).

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
