# Secrets

Production secrets should not be committed in plaintext.

Recommended workflow:

1. Copy the example manifest that matches the target object.
2. Fill in the real values locally.
3. Encrypt the manifest with `sops`.
4. Commit the encrypted `*.enc.yaml` version into this directory.

This repo is configured to encrypt `ops/secrets/*.enc.yaml` with the local age recipient declared in `.sops.yaml`.

If your shell does not already export the age key path, set it first:

```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
```

Typical commands:

```bash
cp ops/secrets/nugusauce-api-secret.example.yaml ops/secrets/nugusauce-api-secret.enc.yaml
cp ops/secrets/nugusauce-api-config.example.yaml ops/secrets/nugusauce-api-config.enc.yaml
sops --encrypt --in-place ops/secrets/nugusauce-api-secret.enc.yaml
sops --encrypt --in-place ops/secrets/nugusauce-api-config.enc.yaml
```

Edit encrypted manifests directly with:

```bash
sops ops/secrets/nugusauce-api-secret.enc.yaml
sops ops/secrets/nugusauce-api-config.enc.yaml
```

Apply manually when needed:

```bash
sops --decrypt ops/secrets/nugusauce-api-secret.enc.yaml | kubectl apply -n nugusauce -f -
sops --decrypt ops/secrets/nugusauce-api-config.enc.yaml | kubectl apply -n nugusauce -f -
```

Expected runtime object names:

- `nugusauce-api-secret`
- `nugusauce-api-config`

Suggested file naming:

- `nugusauce-api-secret.enc.yaml`
- `nugusauce-api-config.enc.yaml`

Config conventions:

- `APP_URL` is the canonical public origin consumed by backend CORS and external links.
- For the current production split, set `APP_URL` to `https://nugusauce.jaehyuns.com`.
- The backend ingress host is configured separately in Helm and should point to `nugusauce.jaehyuns.com`.
