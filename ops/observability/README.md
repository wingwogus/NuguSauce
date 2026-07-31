# Observability runtime

The production cluster runs Loki as a single binary on `k8s-master`. Apply the pinned chart version with the repository-owned values:

```bash
helm upgrade --install loki grafana/loki \
  --version 6.55.0 \
  --namespace observability \
  --create-namespace \
  --values ops/observability/loki-values.yaml \
  --wait \
  --timeout 10m
```

The Loki volume is local to the master node. Both the StatefulSet claim retention policy and the provisioned PV reclaim policy must remain `Retain`. After creating a replacement volume, enforce the PV policy explicitly:

```bash
PV=$(kubectl get pvc storage-loki-0 -n observability -o jsonpath='{.spec.volumeName}')
kubectl patch pv "$PV" -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

Verify ingestion after an upgrade:

```bash
kubectl get pod loki-0 -n observability -o wide
kubectl get --raw '/api/v1/namespaces/observability/services/http:loki:3100/proxy/ready'
kubectl get --raw '/api/v1/namespaces/observability/services/http:loki:3100/proxy/loki/api/v1/query_range?query=%7Bnamespace%3D%22nugusauce%22%7D&limit=5&direction=backward'
```

Do not scale Loki to zero before confirming the live StatefulSet uses `whenScaled: Retain`. Local-path data from a removed node cannot be recovered from the master unless that node's disk is mounted or copied first.
