# ADR 0001: Adopt the AUSI Orchestrator Engineering Blueprint

- Status: Proposed
- Date: 2026-11-04
- Owners: @maintainers (update on review)

## Context

The project codename "AUSI Super Ultra Artificial Universal Superintelligence Orchestrator" implies capabilities no engineering effort can responsibly claim. To develop it as a real system, we need a bounded, testable specification for what is actually being built: a policy-governed multi-model orchestration control plane.

## Decision

Adopt [docs/AUSI-SUPER-ULTRA-ORCHESTRATOR-BLUEPRINT.md](../AUSI-SUPER-ULTRA-ORCHESTRATOR-BLUEPRINT.md) as the reference engineering blueprint. It defines:

- Goals/non-goals with measurable acceptance criteria (§1, §8)
- Component architecture and task finite-state machine (§2)
- Normative data contracts: Task, RoutingDecision, EvidenceRecord, risk tiers T0–T3 (§3)
- API and adapter interfaces (§4)
- Fail-closed policy engine (§5), reliability SLOs (§6), safety red lines (§7)
- Security controls (§9), phased delivery plan P0–P5 (§10), repo layout (§11)

## Alternatives considered

- Free-form vision document: rejected — not testable, invites overclaiming.
- Implement directly without a blueprint: rejected — routing/policy decisions would be unattributable and irreproducible, violating this repository's evidence-over-claims convention (`AGENTS.md`).

## Consequences

- Implementation work proceeds phase by phase (P0 skeleton first); each phase needs exit-criteria evidence linked in PRs.
- The codename remains branding only; all external documentation must describe the bounded system, not "superintelligence."
- Open questions in blueprint §12 must resolve before P1 starts.

## Validation

Note: this ADR is filed under `docs/adr/` ahead of implementation approval. The blueprint itself is a project specification, not part of the zTemplate baseline; if this repository is used purely as a template, relocate both documents to the generated project repository before merging.

- Blueprint passes `make validate-template` (done at time of writing).
- Reviewer sign-off on §7 red lines and §8 eval gates.
- Reconsideration triggers: any requirement found untestable, or pressure to remove human-approval/kill-switch guarantees.
