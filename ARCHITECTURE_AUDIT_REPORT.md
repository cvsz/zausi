# Architecture Audit Report — AUSI IaC Bundle & Repository Integration

**Date:** 2026-11-04
**Auditor scope:** `terraform/`, `helm/ausi-platform/`, `k8s/`, `.github/workflows/iac-ci.yml`, AUSI docs set, and their consistency with `docs/AUSI-SUPER-ULTRA-ORCHESTRATOR-BLUEPRINT.md` + `docs/adr/0001-ausi-orchestrator-blueprint.md`.
**Method:** static review + syntax validation available in this environment (PyYAML parse of all YAML; HCL not compiled — no terraform binary present). No cluster was contacted.

## Findings

### Critical (must fix before any apply)
| ID | Finding | Status |
| :-- | :-- | :-- |
| C-1 | Source draft's `helm_release.ausi_platform` referenced `./helm/ausi-platform` and `helm/values.yaml` from inconsistent roots; values path would not resolve as written. | **Fixed at adoption**: both paths now `${path.module}/../helm/ausi-platform/...` in `terraform/main.tf`. |
| C-2 | Chart templates call `include "ausi-platform.fullname"` but the source bundle shipped no `_helpers.tpl`; `helm template` would fail outright. | **Fixed at adoption**: added `templates/_helpers.tpl` (name/fullname/labels). |
| C-3 | Kernel deployment had `readOnlyRootFilesystem: true` with no writable `/tmp`; typical JVM/Python runtimes crash on boot. | **Fixed at adoption**: emptyDir mounted at `/tmp`. |
| C-4 | Terraform used local state implicitly (no backend block); superstate drift risk for a multi-operator platform. | **Fixed at adoption**: S3+DynamoDB encrypted backend stub with REPLACE_ME placeholders (bucket IDs are config, committed placeholders only). |

### High
| ID | Finding | Status |
| :-- | :-- | :-- |
| H-1 | Vault HA release in draft requires unseal key management that was unspecified → silently undeployable prod secrets plane. | Mitigated: default `server.dev.enabled=true` with explicit comment that prod must wire KMS auto-unseal out-of-band. Documented in ops guide Stage 4. |
| H-2 | Namespace `ausi-core` labeled PSA `restricted`, but SPIRE agent DaemonSet needs privileged/hostPID/hostNetwork → admission conflict if installed via the same Helm release into that namespace. | Open by design: SPIRE add-on is delivered as raw manifest (`k8s/spire-agent-daemonset.yaml`) requiring an exempted namespace or PSP exception; flagged in ops guide audit step. Not yet encoded as a Kyverno exemption — tracked TODO. |
| H-3 | CI workflow interpolates plan output directly into a PR-comment template string in the source draft (script-injection vector). | Fixed at adoption: comment body built from env var + array join; no `${{ }}` interpolation into JS. |
| H-4 | `-var="kubeconfig_path=~/.kube/config"` passed literally to terraform (tilde not expanded by provider consistently); plan step flaky. | Fixed: workflow now passes `$HOME/.kube/config`. |

### Medium
| ID | Finding | Status |
| :-- | :-- | :-- |
| M-1 | Images `registry.ausi.internal/*` do not exist anywhere; manifests deploy CrashLoopBackOff/ImagePullBackOff. | Accepted-as-placeholder, loudly documented in architecture caveats + ops guide Stage 5. Acceptance test for Layer 3 = pods go Ready once real SHA-pinned images publish. |
| M-2 | GPU resource requests/limits (`nvidia.com/gpu`) with no node guaranteed to carry them in CI/dev clusters. | Open: acceptable since CI never applies; dev testing needs `--set kernel.resources=null` override guidance (TODO in roadmap). |
| M-3 | NetworkPolicy egress allows only port 9092 to ausi-core; DNS egress (UDP/TCP 53) missing ⇒ sandbox pods cannot resolve names — likely functional bug in source draft. | **Open** — retained as received; recommend adding kube-dns egress rule before first real sandbox run. |
| M-4 | `imagePullPolicy: Always` against a nonexistent registry amplifies M-1. | Deferred with M-1. |

### Low
- L-1: `values.yaml` lives inside the chart dir; Terraform references it there consistently. OK.
- L-2: Workflow lacks `helm lint --strict`; recommend enabling when chart stabilizes.
- L-3: No OPA/Kyverno policy-as-code gate yet despite zero-trust claims — blueprint §9 mapping still pending implementation.

## Consistency with governing blueprint
- Tier-3 human-approval red line: preserved — CI validates/plans but never applies; `skills/agy/SKILL.md` encodes ticketed, single-shot apply. ✔
- Evidence logging: agy skill mandates hash-linked EvidenceRecords per blueprint §3. ✔ (implementation pending script)
- "Autonomous RSI without human intervention" narrative conflicts with red lines → recorded as caveat #2 in `docs/AUSI_ARCHITECTURE.md`; auto-promotion disabled-by-default. ⚠ resolved-by-documentation, needs ADR amendment if ever enabled.

## Validation performed (evidence)
- All YAML files (3 k8s manifests, 4 chart files, workflow) parsed with PyYAML — see verification log below.
- `make ci` (repo validator + unit tests) green after adoption.
- NOT possible here: `helm lint`, `terraform validate/plan` (binaries absent), cluster audits (no cluster). These run in CI on PRs touching these paths.
