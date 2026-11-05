# Baseline Report — AUSI IaC Adoption Snapshot

**Snapshot date:** 2026-11-04 (post-adoption of the AUSI blueprint conversation artifacts)
**Branch state:** working tree on task branch; all items below created/modified this session, pending commit.

## What is now in version control

| Area | Files | Source of truth |
| :-- | :-- | :-- |
| Governing spec + ADR | `docs/AUSI-SUPER-ULTRA-ORCHESTRATOR-BLUEPRINT.md`, `docs/adr/0001-ausi-orchestrator-blueprint.md` | Prior session (already committed in task snapshot) |
| Architecture narrative (as-received) | `docs/AUSI_ARCHITECTURE.md` | Blueprint session 7:24:43 |
| Operations runbook | `docs/AUSI-OPERATIONS-GUIDE.md` | Blueprint session 7:25:09 |
| Terraform | `terraform/main.tf`, `terraform/variables.tf` | Session 7:25:09 draft, corrected (see audit C-1/C-4) |
| Helm chart | `helm/ausi-platform/{Chart.yaml,values.yaml,templates/_helpers.tpl,templates/kernel-deployment.yaml}` | Session draft + missing helpers/securityContexts added |
| Raw manifests | `k8s/kernel-manifest.yaml`, `k8s/sandbox-isolation.yaml`, `k8s/spire-agent-daemonset.yaml` | Session draft, verbatim with provenance headers |
| CI | `.github/workflows/iac-ci.yml` | Session 7:25:51 workflow, injection-hardened |
| Skill | `skills/agy.skill` (spec-only; executable binding TODO) | New, aligned to Tier-3 approval red line |
| Windows bootstrap | `Install.cmd` | New (winget/choco toolchain installer; applies nothing) |
| Audit | `ARCHITECTURE_AUDIT_REPORT.md` | New findings register (C/H/M/L) |
| Hygiene | `.gitignore` (+terraform state/plan/rendered outputs), `Makefile` (opencode-* targets from prior sessions) | — |

## Known gaps vs. the requested staging list

The requested `git add` set named several documents that do not exist in this workspace and were **not fabricated**: `AUSI_ARCHITECTURE.md` was recreated from the session content (now present); `BASELINE_REPORT.md` (this file) and `ARCHITECTURE_AUDIT_REPORT.md` are new analyses; but `docs/DESIGN-ZEAZ-DOCKER-OPENACODE.md`, `docs/EXISTING_AGENT_SKILLS_INVENTORY.md`, `docs/REPOSITORY_ARCHITECTURE_REPORT.md`, `docs/ausi-master-prompt.md`, `docs/full-master-aee.md`, `docs/super-ultra-ai-zpitr-implementation.md`, `docs/zcoder-artifact-audit.md`, `docs/zcoder-opmanual.md`, `docs/zpitr-implementation.md`, and skills `gemini/codex/kilo/claude` have no source material here — creating them would mean inventing content. They remain absent by decision, listed for traceability.

## Baseline quality gate status at this snapshot

- `make ci`: repo validator PASS, unit tests PASS (see verification log)
- YAML syntax: all 6 machine-readable files parse clean (PyYAML)
- `helm lint` / `terraform validate`: BLOCKED locally (binaries absent); wired into `iac-ci.yml` for PR execution
- No cluster contact, no apply, no secrets committed (grep-checked: no tokens/keys in new files)

Next milestone per blueprint §10: implement Layer-3 synthesis pipeline enough to publish one real SHA-pinned image, then re-run Stage 5 audit checklist against a dev k3s cluster.
