# Verification Design, Critical Readiness, and Deviation

## Verification before implementation

Derive verification from acceptance criteria and risk before coding. Do not wait until implementation is complete to decide what would prove success.

Typical intensity:

- **P0:** focused check for the claimed change.
- **P1:** relevant tests plus typecheck/build or focused regression where applicable.
- **P2:** relevant unit, integration, regression, contract, and failure-path evidence.
- **P3:** add risk-specific evidence such as idempotency, concurrency, fault injection, recovery, invariant checks, long-run/operational evidence, or security checks as appropriate.

Do not copy every verification category into every task; use only what can prove the current risk-relevant behavior.

## Critical readiness additions

For P3, explicitly define:

- major failure modes
- detection evidence
- rollback/recovery strategy
- independent verification role
- independent review role
- operational/invariant evidence needed before acceptance

The same agent should not be the sole implementer, verifier, and final reviewer of critical work.

## Rollback / recovery

For P2/P3 answer, as relevant:

- Can code/config be rolled back safely?
- Is data/state migration involved?
- Are any side effects irreversible?
- How is partial execution detected and contained?
- What must be preserved for recovery/audit?

## Baseline deviation during implementation

`gad-governance` owns D0/D1/D2 classification. Implementation should surface evidence:

- **Incidental:** implementation detail only; approved scope/contracts/risk remain unchanged.
- **Material:** dependency, meaningful internal interface, persistence, module impact, or verification strategy changes.
- **Fundamental:** scope/architecture/public contract changes, critical risk escalation, or irreversible migration.

Do not normalize a material/fundamental deviation as "implementation detail". Stop affected work when governance requires G4 or renewed readiness.
