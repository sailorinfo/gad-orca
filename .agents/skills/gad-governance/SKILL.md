---
name: gad-governance
description: Use when a GAD-managed project needs lifecycle, change/risk classification, governance profile, human-gate, controlled-artifact, baseline-deviation, project-state, source-of-truth, cross-skill handoff, or GAD skill-evolution decisions. Do not use it to design architecture or implementation.
---

# GAD Governance

## Purpose

Interpret and enforce the GAD lifecycle. Convert current project facts, state, change scope, risk, approvals, artifact status, and ownership into one explicit governance decision: what is allowed now, what is forbidden, which gate is required, which skill owns the next work, and which state transition is legal.

Do not perform project definition, architecture design, implementation design, solution research, coding, debugging, review, or deployment on behalf of the skills that own those responsibilities.

## Modes

**Bootstrap mode:** use when the project has not yet established its GAD project baseline. Govern from this skill, the approved GAD protocol, explicit user instructions, and observable repository facts.

**Project mode:** use after project governance artifacts exist. Read the required project artifacts before deciding anything.

## Mandatory context

In project mode, read:

- `PROJECT.md`
- `PROJECT_RULES.md`
- `DEVELOPMENT_WORKFLOW.md`
- `PROJECT_STATUS.md`

Also read `ARCHITECTURE.md` and relevant ADRs for architecture-affecting work. For a delivery batch, read the approved batch artifacts that should exist at the current state plus any current A2 working package that is being considered for a gate.

If an artifact should exist for the current GAD state but is missing or contradictory, return `GOVERNANCE BLOCKED`; do not invent the missing fact.

## Authority resolution

Separate **factual authority** from **authorization authority**.

For project facts and semantics, prefer: approved A1 baselines -> governed `PROJECT_STATUS.md` state records -> current repository/runtime facts -> A2 working artifacts -> current user clarification -> ordinary chat context -> conversation recap/summary.

For permission to perform a gated action, only a valid explicit scoped approval for the applicable gate authorizes the action. A conversation recap, summary, inferred intent, prior enthusiasm, or working draft never proves approval.

If a lower-authority source conflicts with a higher-authority source, use the higher-authority source and report the conflict. A recap/summary must never override a controlled artifact, explicit scoped approval, or governed state record.

## Governance loop

1. Resolve authoritative current project and batch state.
2. Resolve any source-of-truth conflicts that could change the decision.
3. Finalize change class and current risk; resolve the governance profile.
4. Check whether the requested action is legal in the current state.
5. Check artifact ownership and mutation permissions.
6. Check whether a human gate is mandatory and whether a valid scoped approval already exists.
7. Check baseline deviation if implementation is already in progress.
8. Return allowed actions, forbidden actions, required gate, artifact permissions, next owner, and next legal state.

Load `references/lifecycle-and-profiles.md` for state, change/risk/profile, transition, or baseline-deviation decisions.
Load `references/gates-and-artifacts.md` for approval, controlled mutation, artifact ownership/lifecycle, retention, promotion, source-of-truth, or cleanup decisions.
Load `references/evolution.md` for any `gad-*` skill evolution question.

## Governance baseline contribution

During initial G2 preparation, governance owns the Governance Baseline Proposal. Draft only governance-owned content: project rules, development-workflow governance, gate/profile application, artifact/state semantics, and the proposed state-transition/action package. Consume the Architecture Proposal as a constraint; do not redesign architecture. Consolidate the governance contribution with the architecture contribution into one exact G2 package for approval.

## Core rules

- Governance is proportional to risk; do not force heavy process onto trivial work.
- Change class measures scope of impact; risk measures consequence of failure. Never average away a critical risk dimension.
- `gad-governance` is the final classification authority. Other skills may provide evidence and recommend C/R/P changes, but they must not finalize or persist a new classification as authoritative without governance.
- Financial-domain context alone does not make work R4. Use the concrete failure path and control authority defined in `lifecycle-and-profiles.md`.
- Approval must be explicit and scoped to a specific gate and target. Positive-sounding discussion is not approval. Non-rejection is not confirmation, and providing requested clarification does not authorize implementation or controlled mutation.
- Controlled artifacts may be read and analyzed freely, but may only be created, modified, renamed, promoted, or deleted under the gate or pre-authorized mechanical action that permits that mutation.
- Mechanical synchronization of already-authorized state may update `PROJECT_STATUS.md` without a second approval.
- New evidence may escalate classification or risk immediately. High-governance downgrades require evidence and must not be used merely to save process.
- Do not bypass another GAD skill's ownership. Use an explicit handoff.
- A role boundary is a hard stop: once another GAD skill owns the next substantive work, governance must stop performing that work. The same agent/session may continue only by explicitly loading/invoking the owning skill and operating under that skill's contract. If the owning skill is unavailable, return `ROUTE_BLOCKED`; never substitute with a best-effort version of that skill's work.
- Every cross-skill handoff must identify: `from_skill`, `next_owner`, `output_or_evidence`, `decision_needed`, `current_state`, `required_gate`, and `blockers` when any exist.
- After missing information is supplied, resume the governed workflow from the correct state and gate. Clarification completion alone never grants authority to implement, integrate, or mutate controlled artifacts.
- Never self-modify this skill or any other `gad-*` skill. Evolution is proposal-only until explicit G4 approval.

## Output contract

Return a compact governance decision containing:

- project state
- batch state, if any
- finalized change class
- finalized risk level
- governance profile
- allowed actions
- forbidden actions
- required gate, if any
- artifact permissions
- next owner / next skill
- next legal state
- blockers or conflicting facts
- handoff fields when work transfers to another skill

If the decision is blocked, name the missing or contradictory fact and the minimum resolution needed.

## Exit

A governance pass is complete only when the caller has one unambiguous legal next action, a valid handoff, or a clearly stated blocker. Do not end with vague advice such as “proceed carefully.”
