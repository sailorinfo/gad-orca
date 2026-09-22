---
name: gad-implementation-readiness
description: Use when a feature, module, fix, or delivery batch needs pre-implementation readiness to refine the value slice, inspect current state, verify architecture fit, allocate capabilities, challenge over-design, assess impact and risk, decide research and parallelization, and define verification before implementation is authorized.
---

# GAD Implementation Readiness

## Purpose

Decide whether a proposed delivery batch is ready to implement and, if so, prepare the exact implementation/baseline proposal that can be approved or established under the applicable profile. This skill owns pre-implementation design for the current value slice; it does not perform production implementation.

Apply `gad-governance` for authoritative state, final change/risk/profile, gate requirements, source-of-truth, artifact permissions, and reclassification. This skill may recommend reclassification with evidence but is not the classification authority.

## Modes by governance profile

Use the profile finalized by `gad-governance`:

- **P0 FAST:** usually skip full readiness; only use a minimal baseline when governance routes here.
- **P1 STANDARD:** use lightweight readiness when scope and risk are clear.
- **P2 STRICT:** use full readiness.
- **P3 CRITICAL:** use full readiness plus explicit failure/recovery, independent verification, and independent review planning.

If classification/profile is missing, stale, or new evidence could materially change it, hand classification evidence to `gad-governance` before selecting the readiness path.

## Mandatory context

In an active GAD project, read `PROJECT.md`, `ARCHITECTURE.md`, `PROJECT_RULES.md`, `DEVELOPMENT_WORKFLOW.md`, and `PROJECT_STATUS.md`, then progressively inspect only the task-relevant code, tests, interfaces/contracts, schemas/configuration, ADRs, and recent related `RESULT.md` evidence.

If a controlled artifact should exist for the current state but is missing or contradictory, stop with `READINESS BLOCKED` rather than inventing it.

## Core workflow

1. Recover current context and freshness of relevant baselines.
2. Refine the request into a small, independently verifiable value slice.
3. Analyze current implementation, reuse, tests, and dependencies.
4. Check architecture fit and ownership boundaries.
5. Allocate each required capability to the least-complex suitable mechanism.
6. Run internal reuse checks and decide whether the research gate is triggered.
7. If research is required, produce a bounded Research Brief, hand off to `gad-solution-research`, and stop the readiness role until Research Findings return.
8. Integrate returned research into the project-specific Build/Adopt/Adapt decision; research does not make this final decision.
9. Challenge the proposed design for over-design.
10. Analyze impact, risk evidence, rollback/recovery, and parallelization; return reclassification evidence to governance when needed.
11. Design observable verification before implementation begins.
12. Produce the applicable Execution Baseline: a lightweight baseline for gate-free P0/eligible P1, or an exact draft package for G3-gated work.

Load `references/readiness-method.md` for value-slice, current-state, architecture-fit, research handoff, impact, proposal, and gated/gate-free baseline guidance.
Load `references/capability-and-parallelization.md` for Program/Tool/MCP/Skill/Agent/Orchestration allocation and worker-mode decisions.
Load `references/verification-and-deviation.md` for verification design, critical-readiness additions, rollback/recovery, or implementation deviation rules.

## Research hard boundary

Readiness may inspect internal project facts and existing dependencies directly. Once the external Research Gate is `TRUE`, it must not perform substantive external candidate/official-solution research itself. It must create the Research Brief and hand off to `gad-solution-research`. A trivial factual lookup that does not compare/select external solutions is not a substitute for the research handoff when the gate is triggered.

## Never

- Do not modify production code, install dependencies, run migrations, or start implementation workers before implementation is authorized.
- Do not silently change the architecture baseline; report an Architecture Concern to `gad-governance` and route to `gad-system-architecture` when needed.
- Do not finalize C/R/P; submit evidence/recommendations to `gad-governance`.
- Do not perform substantive external solution research after the Research Gate is triggered.
- Do not make final external-solution decisions from generic research without project-context integration.
- Do not treat clarification, research completion, or a positive response as G3 approval unless governance recognizes explicit scoped approval.
- Do not turn a large project phase into one oversized batch merely because agents can parallelize it.

## Output contract

Return an `IMPLEMENTATION PROPOSAL` containing objective, authoritative governance classification/profile, scope/non-scope, current state, relevant architecture, recommended design, capability allocation, reuse findings, research findings or reason research is unnecessary, alternatives/trade-offs, over-design assessment, impact, risks, rollback/recovery where needed, parallelization/worker strategy, verification strategy, controlled artifacts to create/modify, baseline dependencies, and open blockers.

When research is required but not yet complete, output a `RESEARCH HANDOFF` with the bounded Research Brief and exit as `RESEARCHING`.

For G3-gated work, prepare a **draft-only** execution baseline package: requirements draft, execution-plan draft, verification-plan draft, and research-retention proposal/draft if applicable. Use existing `writing-plans` only to help structure the draft; the draft is not authoritative until G3.

For a governance-approved gate-free P0/eligible P1 path, establish a lightweight execution baseline containing at least objective, scope, do-not-touch boundaries, expected change, and verification; it may remain in task/orchestration context instead of formal Markdown files.

## Exit / handoff

Normal exits are:

- `RESEARCHING` -> hand Research Brief to `gad-solution-research`.
- `BLOCKED` -> return blocker and minimum resolution to `gad-governance`.
- `READY_FOR_APPROVAL` -> hand the exact G3 draft package to `gad-governance`.
- `BASELINED` on an eligible gate-free path -> after governance confirms no G3 is required and the lightweight baseline is established, hand execution context to existing engineering skills / Orca orchestration.
- `CANCELLED` when cancellation is governed.

After valid G3 approval, promote the exact approved baseline package under the applicable artifact owners and hand off execution. This skill does not become the coding agent.

A role boundary is a hard stop: the same agent/session may continue only after explicitly loading/invoking the next owner's skill contract.

Skill evolution is proposal-only and follows `gad-governance`; never self-modify.
