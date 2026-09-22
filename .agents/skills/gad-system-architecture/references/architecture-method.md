# Architecture Method

Use this reference for initial high-level architecture design.

## Architecture scope

Architecture defines stable boundaries and responsibilities that should remain meaningful across multiple delivery batches. Prefer domain/capability boundaries over generic code-layer taxonomies such as `controllers/services/utils`.

Architecture should decide only what must be stable across batches. Ordinary implementation choices should remain deferred until `gad-implementation-readiness`.

## Module boundary test

For each proposed module, answer:

- **Purpose** — what stable system responsibility exists here?
- **Owns** — which state, rules, or semantic responsibility belongs here?
- **Consumes** — which stable inputs does it depend on?
- **Produces** — which stable outputs/contracts does it expose?
- **Must not do** — which responsibilities are explicitly outside its authority?

Evaluate boundaries using:

- responsibility cohesion
- change coupling
- data/state ownership
- dependency direction

A boundary is suspect when routine changes require understanding or mutating several other modules' internals.

## Contracts

At architecture time, define contract **semantics**, producers/consumers, key invariants, and stability expectations. Defer detailed field schemas unless they are required to establish the boundary.

Distinguish:

- data dependency
- control dependency
- infrastructure dependency

Access to data is not authority to control behavior.

## Shared/platform capabilities

Extract a platform/shared capability only when multiple modules have recurring common needs with meaningful reuse, such as configuration, secrets, observability, storage, or external-access infrastructure. Do not create a platform layer merely for architectural symmetry.

## Workerability and cognitive load

Review whether future work can be owned by a worker with bounded context:

- explicit ownership
- explicit contracts
- clear do-not-touch boundaries
- low shared mutable state
- local verification possible
- minimal need to understand unrelated internals

Flag high cognitive coupling, hidden shared state, god modules, and ambiguous data ownership.

## Deferred-decision boundary

Unless a choice is itself a stable system constraint, defer these to delivery readiness:

- ordinary libraries/SDKs
- implementation algorithms
- detailed storage/runtime tuning
- function/class structure
- Program vs Tool vs MCP vs Skill vs Agent vs Orchestration allocation
- worker count/task partitioning
- file-level implementation plan

When asked to decide one of these during architecture, record the relevant architecture constraints, mark the decision `DEFERRED_TO_READINESS`, and hand off rather than giving a preliminary implementation choice.

## Architecture over-design challenge

Before finalizing:

- Which module lacks a current use case?
- Which abstraction exists only for hypothetical future variants?
- Which distributed or agentic mechanism could remain ordinary code for now?
- Which shared layer has only one consumer?
- Which decisions can be deferred safely?
- Would removing a proposed component still satisfy the approved project definition?

Record deferred decisions explicitly instead of forcing premature choices.

## Development dependency map

Architecture may define capability dependencies and broad phases. It must not create file-level implementation steps, worker assignments, capability-allocation decisions, or execution DAGs for future batches.
