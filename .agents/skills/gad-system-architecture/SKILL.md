---
name: gad-system-architecture
description: Use when an approved project definition needs high-level system boundaries, domains, modules, responsibilities, dependencies, critical contracts, data/control flows, architecture risks, development dependencies, or an architecture-change proposal. Do not use it for batch-level implementation design or capability allocation.
---

# GAD System Architecture

## Purpose

Create the minimum sufficient high-level architecture that supports the approved project definition and later small-batch delivery. Own stable system boundaries, responsibilities, dependencies, contract semantics, and architecture-level risks; defer implementation detail until delivery readiness.

Apply `gad-governance` for state, final C/R/P, permissions, G2/G4, source-of-truth, handoff, artifact ownership, and controlled mutation semantics.

## Modes

**Greenfield:** define high-level target architecture from approved project intent.

**Brownfield:** recover current architecture facts first, compare them with the approved project definition, then propose an incremental target architecture. Current runtime and compatibility facts outrank an imagined ideal architecture.

**Architecture-change mode:** use only when `gad-governance` has routed an active project back for a controlled architecture change.

## Mandatory context

Read approved `PROJECT.md`. Read existing `PROJECT_RULES.md` if present. In brownfield or architecture-change mode, progressively inspect current topology, critical contracts, external systems, runtime/deployment shape, affected ADRs, and enough code/data structure to establish real boundaries.

## Core workflow

1. Recover project goals, non-goals, use cases, and constraints.
2. Define the system boundary and external-system boundary.
3. Identify core domains/capabilities.
4. Define module boundaries and ownership.
5. Define each module's purpose, owns, consumes, produces, and must-not-do responsibilities.
6. Define dependency direction and critical contract semantics.
7. Define high-level data flows and control flows.
8. Identify genuinely shared/platform capabilities.
9. Review architecture risk, cognitive coupling, and workerability.
10. Run an architecture over-design challenge.
11. Produce a development dependency map / high-level phases.
12. Record deferred decisions and ADR candidates.

Load `references/architecture-method.md` for boundary, ownership, workerability, deferred-decision, and over-design guidance.
Load `references/brownfield-and-change.md` for brownfield recovery, architecture research gates, ADR candidates, or architecture-change mode.

## Never

- Do not design concrete classes, functions, detailed schemas, worker task lists, or implementation task DAGs.
- Do not choose ordinary libraries, SDKs, internal algorithms, or implementation mechanisms unless the decision is itself a stable architecture constraint.
- Do not decide whether a normal delivery capability should be Program, Tool, MCP, Skill, Agent, or Orchestration. Record it as deferred and route that decision to `gad-implementation-readiness`.
- Do not start implementation, install dependencies, or launch coding workers.
- Do not create or mutate formal `ARCHITECTURE.md` or ADRs before the governing G2/G4 approval.
- Do not author or semantically mutate `PROJECT_RULES.md`, `DEVELOPMENT_WORKFLOW.md`, or `PROJECT_STATUS.md`; those are `gad-governance` artifacts.
- Do not finalize C/R/P. Provide architecture-risk evidence/recommendations to `gad-governance`.

## Research boundary

If a material architecture decision needs external evidence, produce a decision-focused Research Brief and hand off to `gad-solution-research`. Once the research gate is triggered, stop substantive external candidate research under the architecture role. Resume architecture only after Research Findings return.

## Output contract

Return an `ARCHITECTURE PROPOSAL` containing architecture context/goals/principles, system boundary, domains/modules, responsibilities, dependencies, critical contract semantics, high-level data/control flows, external systems, shared/platform capabilities, AI/agent boundaries if relevant, architecture risks, workerability findings, over-design findings, development dependency map, deferred decisions, ADR candidates, research evidence used, and open questions.

Architecture-risk or change-class observations are recommendations only; governance finalizes classification.

## Exit / handoff

For initial architecture, hand the Architecture Proposal and ADR candidates to `gad-governance`. Governance owns the Governance Baseline Proposal, consolidates the exact G2 package, and requests G2. This skill must not fill the governance-artifact gap itself.

After valid G2, this skill semantically owns promotion of the exact approved `ARCHITECTURE.md` and ADR content; `gad-governance` owns promotion of project rules/workflow and state synchronization through `BASELINED` to `ACTIVE`. Mechanical promotion may be coordinated when the approved action package allows it.

For active-project architecture changes, return an Architecture Change Proposal to `gad-governance` for G4. Do not treat architecture approval as authorization to implement a delivery batch.

A role boundary is a hard stop: the same agent/session may continue only after explicitly loading/invoking the next owner's skill contract.

Skill evolution is proposal-only and follows `gad-governance`; never self-modify.
