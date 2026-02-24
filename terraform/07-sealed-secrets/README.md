# terraform/sealed-secrets

Deploys the Bitnami Sealed Secrets controller into `kube-system`.

## What this does

Installs the controller that watches for `SealedSecret` custom resources and
decrypts them into plain `kubernetes_secret` objects in-cluster. Encrypted
SealedSecret YAMLs are safe to commit to git.

## Layer placement

Layer 3 — apply after MetalLB, before any service modules that depend on
SealedSecrets.

## Critical: back up the master key

The controller generates a private key on first install stored in:

    kube-system/sealed-secrets-key (label: sealedsecrets.bitnami.com/sealed-secrets-key)

**Back this up to Bitwarden before destroying the cluster:**

```bash
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > sealed-secrets-master-key.yaml
```

Store `sealed-secrets-master-key.yaml` in Bitwarden as a secure note.

## Rebuilding with an existing key

To preserve SealedSecrets across a cluster rebuild:

```bash
# On new cluster, before applying this module:
kubectl apply -f sealed-secrets-master-key.yaml

# Now apply the module — controller picks up the existing key
terraform apply
```

If you apply the module first, it generates a new key and all existing
SealedSecrets become unrecoverable.

## Creating SealedSecrets (on Astraeus)

Install kubeseal:
```bash
# Arch Linux
paru -S kubeseal  # or download binary from GitHub releases

# Fetch the public key (one-time, or after key rotation)
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  > pub-cert.pem
```

Seal a secret:
```bash
# Create the plain Secret manifest (never commit this)
kubectl create secret generic my-secret \
  --namespace=my-namespace \
  --from-literal=password=supersecret \
  --dry-run=client -o yaml > plain-secret.yaml

# Seal it (safe to commit)
kubeseal --format=yaml --cert=pub-cert.pem < plain-secret.yaml > sealed-secret.yaml

# Apply to cluster
kubectl apply -f sealed-secret.yaml
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `chart_version` | string | `"2.16.1"` | Helm chart version |

## Outputs

| Name | Description |
|------|-------------|
| `controller_name` | Controller deployment name in kube-system |
| `chart_version` | Deployed chart version |
