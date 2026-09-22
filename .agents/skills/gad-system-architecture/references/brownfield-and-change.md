# Brownfield Architecture, Research, and Change

## Brownfield recovery

Before proposing target architecture, recover current facts progressively:

1. project definition and existing controlled architecture records
2. repo/module topology
3. critical runtime/deployment shape
4. critical data/contract boundaries
5. external systems and integration points
6. active compatibility commitments

Prefer incremental adaptation over rewrite unless evidence shows the current structure cannot meet the approved project definition at acceptable cost/risk.

## Architecture research gate

Use `gad-solution-research` when an architecture decision depends on external evidence, especially when:

- the core architecture pattern is genuinely uncertain
- an unfamiliar core infrastructure choice is being considered
- migration/lock-in cost is high
- mature industry solutions may materially change the design
- brownfield compatibility or migration risk is significant

The research brief must identify the decision to support, current architecture constraints, alternatives/questions, and what evidence could change the architecture choice.

## ADR candidates

Create an ADR candidate only when a decision is long-lived, materially constrains multiple modules, has credible alternatives, is expensive to reverse, or future maintainers are likely to ask "why?".

ADR candidates remain working material until the governing G2/G4 approval promotes them.

## Architecture-change mode

For an active project, do not redesign the whole system. Produce a focused Architecture Change Proposal containing:

- current baseline
- proposed change
- reason and evidence
- affected modules/contracts/data/control flows
- migration/compatibility impact
- active-batch impact
- risks and recovery/rollback considerations
- ADR changes/candidates

Return to `gad-governance` for G4. After an approved architecture change, affected delivery batches must re-check readiness rather than continuing on a stale baseline.
