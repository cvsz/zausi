# AUSI Model Developer — Terraform + Helm Operations Guide

**Date:** 2026-11-04
**Scope:** Step-by-step runbook to initialize, validate, and execute the deployment pipeline defined in `terraform/` and `helm/ausi-platform/`. Adopted from the blueprint session with repo-specific path corrections.

> Prerequisite: read the Standing Caveats in `docs/AUSI_ARCHITECTURE.md` first. Placeholder images (`registry.ausi.internal/*`) will not pull; Stages 1–3 are safe against any cluster; Stages 4–5 require real artifacts and credentials.

---

## Stage 1: Local Environment Preparation & Tooling Verification

1. **Verify Binary Dependencies** — `terraform` (>= 1.5.0), `helm` (>= 3.12), `kubectl`:
   ```bash
   terraform version
   helm version
   kubectl version --client
   ```

2. **Configure Cluster Context**:
   ```bash
   export KUBECONFIG=~/.kube/config
   kubectl cluster-info
   ```

3. **Verify Node Capabilities** (GPU workers must carry labels matching `var.gpu_node_selector`):
   ```bash
   kubectl get nodes -l accelerator/gpu=nvidia-a100
   ```

## Stage 2: Helm Chart Validation & Packaging

From the repository root:

```bash
helm lint helm/ausi-platform
```

Dry-run rendering without touching a cluster:

```bash
helm template ausi-platform helm/ausi-platform \
  --values helm/ausi-platform/values.yaml \
  --namespace ausi-core > rendered-debug.yaml
```

*Inspect `rendered-debug.yaml` to confirm pod security contexts, volume mounts, and resource requests. Do not commit this file.*

## Stage 3: Terraform Initialization & Execution Plan

```bash
cd terraform
terraform init            # downloads kubernetes/helm/aws providers; needs real S3 backend IDs first,
                          # or use `terraform init -backend=false` for offline validation only
terraform validate
terraform plan -out=ausi-deployment.tfplan
```

Review the plan output carefully: it lists namespace creation, the Vault Helm release, and the ausi-platform release.

## Stage 4: Execution & Cluster Deployment

```bash
terraform apply ausi-deployment.tfplan
```

Verify Vault came up (dev mode by default — see comment in `main.tf`; do not unseal-copy anything into VCS):

```bash
kubectl get pods -n vault
```

## Stage 5: Post-Deployment Verification & Health Auditing

1. **Core component readiness:**
   ```bash
   kubectl get pods -n ausi-core -l app=ausi-kernel
   ```
   Expect ImagePullBackOff until Layer 3 registry artifacts exist — that is the acceptance signal for the synthesis pipeline, not a networking bug.

2. **SPIRE attestation socket:**
   ```bash
   kubectl exec -it deployment/ausi-platform-kernel -n ausi-core -- ls -l /tmp/spire-agent/public/api.sock
   ```

3. **Network isolation audit (gVisor + NetworkPolicies):**
   ```bash
   kubectl get networkpolicy -n ausi-sandbox
   kubectl get runtimeclass gvisor
   ```

## Automation

`.github/workflows/iac-ci.yml` runs Stages 2–3 equivalents (lint, template, fmt, validate, mock-kubeconfig plan) on every PR touching `terraform/**` or `helm/**`. Apply (Stage 4) is deliberately **not** automated — per the governing blueprint, production mutation requires a human operator.
