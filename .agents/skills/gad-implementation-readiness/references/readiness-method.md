# Implementation Readiness Method

## Value-slice refinement

Turn the request into a delivery unit that is small enough to implement, verify, and integrate independently.

Define:

- objective
- scope
- non-scope
- inputs/outputs or observable behavior
- constraints
- acceptance criteria
- dependencies
- unknowns

Flag `BATCH TOO LARGE` when the request spans multiple independently valuable or independently verifiable capabilities. Propose a decomposition, but do not silently change the user's intended scope.

## Current-state analysis

Before designing new capability, inventory task-relevant existing facts:

- existing implementation and extension points
- existing public/internal contracts
- existing dependencies and utilities
- existing tools/MCP/skills/platform capabilities
- tests and verification mechanisms
- recent related results/ADRs

Prefer reuse before introducing new mechanism.

## Architecture fit

Answer:

- Which module owns the capability?
- Who produces/consumes the relevant data?
- Does the dependency direction match `ARCHITECTURE.md`?
- Does the proposal violate a module's `Must Not Do` boundary?
- Does it introduce hidden coupling or shared mutable state?

If architecture must change, return an `ARCHITECTURE CONCERN` to `gad-governance`; do not rewrite architecture in place.

## Classification checkpoint

Use C/R/P finalized by `gad-governance`. Readiness may discover new evidence and recommend escalation/downgrade, but must hand that evidence back to governance for finalization before choosing a materially different profile path or persisting classification in governed status.

## Reuse and Research Gate

Search in this order:

1. current project implementation
2. existing dependencies/utilities
3. existing Tool/MCP/Skill/platform capability
4. external evidence through `gad-solution-research`

Trigger the external Research Gate for unfamiliar core technology, major third-party dependency, high migration/lock-in cost, security/financial-critical choices, or where a mature ecosystem may materially change the design.

Before research, create a bounded Research Brief containing:

- problem
- decision needed
- current implementation/architecture context
- constraints
- compatibility requirements
- governance/risk context or finalized profile when one exists
- questions to answer
- out-of-scope topics
- owning skill to return findings to

When the Research Gate is `TRUE`, readiness must not itself perform substantive external candidate comparison, library/SDK selection research, or broad official-solution investigation. Handoff to `gad-solution-research`, enter `RESEARCHING`, and resume only after Research Findings return.

A narrow external factual check is allowed only when it does not substitute for a triggered research decision. If the fact could materially change candidate selection or design, include it in the Research Brief instead.

## Research return

On return from `gad-solution-research`:

1. verify that findings answer the brief and declare uncertainties
2. integrate the evidence with project constraints
3. decide Build / Adopt / Adapt for this batch
4. record why material alternatives were not selected
5. identify what changed condition would reopen the decision
6. return any new classification evidence to `gad-governance`

Research recommendation is evidence, not the final implementation decision.

## Over-design challenge

Ask:

- Can ordinary deterministic code solve this?
- Is a new dependency/layer/infrastructure component needed now?
- Is future speculation driving current complexity?
- Is a Tool/Skill/Agent being introduced where a lower-complexity mechanism is enough?
- Is parallelization increasing integration cost more than delivery speed?
- What can be removed while still satisfying the batch?

Include the result in the proposal.

## Impact analysis

Inspect only relevant dimensions:

- product/user behavior
- feature behavior
- module boundaries
- data/schema/semantics
- API/contracts
- code ownership/surface
- runtime/performance/concurrency
- security/credentials/permissions
- operations/deployment/observability
- rollback/recovery

Mark each important dimension as affected, unaffected, or unknown. New evidence may justify a reclassification recommendation to `gad-governance`.

## Baseline branch

### G3-gated path

For P2/P3 and any P1 case governance marks gated, prepare the exact draft package that will be reviewed at G3. Do not treat the package as authoritative before approval.

Expected draft package when applicable:

- Requirements draft
- Execution Plan draft
- Verification Plan draft
- Research draft/retention decision

Exit `READY_FOR_APPROVAL` and hand the exact package to `gad-governance`.

### Gate-free P0 / eligible P1 path

When `gad-governance` explicitly determines G3 is not required, still establish a lightweight baseline before implementation. Record at least:

- Objective
- Scope
- Do-not-touch
- Expected Change
- Verification

The baseline may live in Orca Task Spec / concise execution context. Once governance confirms the gate-free baseline is established, transition through `BASELINED` and hand off to execution. Do not create unnecessary formal task files merely to imitate P2/P3.

## Proposal discipline

The proposal must explain why the recommended design fits current constraints, why material alternatives were not chosen, and which changed conditions would justify revisiting the decision.
