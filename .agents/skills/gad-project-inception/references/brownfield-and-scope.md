# Brownfield Inception and Scope Challenge

## Brownfield mode

Use when code or a deployed system already exists and the project definition is being established or fundamentally revised.

Inspect only enough current reality to understand what users already have and what constraints are already real. Prefer observable behavior and existing controlled project records over aspirational documentation.

At minimum distinguish:

- existing user-visible capability
- existing project/product boundary
- current consumers and external systems
- commitments or compatibility constraints that cannot be ignored
- existing `PROJECT.md` / `PROJECT_STATUS.md` if present

Do not turn brownfield inception into a code review or architecture redesign.

## Scope challenge

Before asking for G1, challenge the proposal:

- Is a possible future need being treated as a current goal?
- Is a proposed solution being mistaken for the underlying requirement?
- Are goals too broad to know when the project succeeds?
- Are non-goals missing where scope creep is likely?
- Can the project boundary be smaller without losing the intended outcome?
- Which decisions can safely be deferred until architecture or implementation readiness?

Prefer explicit deferral over premature decisions.

## Blocking conditions

Return `PROJECT DEFINITION BLOCKED` rather than guessing when a missing fact materially changes project identity, scope, or success criteria. State the missing decision, why it matters, and the smallest clarification needed.
