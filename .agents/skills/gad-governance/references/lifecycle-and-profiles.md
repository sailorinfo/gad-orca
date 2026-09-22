# GAD Lifecycle and Governance Profiles

Use this reference when resolving project state, delivery-batch state, change class, risk, governance profile, legal transitions, or baseline deviation.

## Project lifecycle

`IDEA -> DEFINING -> DEFINED -> ARCHITECTING -> BASELINED -> ACTIVE -> MAINTENANCE -> RETIRED`

- `IDEA`: concept only; discussion and problem clarification are allowed, formal implementation is not.
- `DEFINING`: `gad-project-inception` prepares a Project Definition Proposal.
- `DEFINED`: G1 has approved the project definition; `PROJECT.md` is authoritative.
- `ARCHITECTING`: `gad-system-architecture` prepares the architecture contribution while `gad-governance` prepares/consolidates the project-governance baseline package.
- `BASELINED`: the exact G2-approved architecture/governance artifacts have been promoted. This is a transition state inside completion of G2, not the normal steady state after G2.
- `ACTIVE`: normal delivery-batch loop. A successful G2 completion must leave the project in `ACTIVE` unless governance explicitly places it into another legal post-baseline state.
- `MAINTENANCE`: the project mainly receives fixes, dependency work, operational changes, and small enhancements through the same delivery governance.
- `RETIRED`: active development is intentionally ended.

### Project transition rules

- `IDEA -> DEFINING`: project-definition work starts.
- `DEFINING -> DEFINED`: valid G1 approves the exact Project Definition Proposal and `PROJECT.md` is promoted.
- `DEFINED -> ARCHITECTING`: architecture/governance baseline preparation starts.
- `ARCHITECTING -> BASELINED -> ACTIVE`: valid G2 approves the exact Project Baseline package, approved artifacts are promoted, and governed status is synchronized. Do not leave a successfully completed G2 project parked in `BASELINED`.
- Any semantic change to an approved project baseline follows G4 and the applicable owning skill before returning to a legal active state.

## Delivery lifecycle

`PROPOSED -> CLASSIFIED -> READINESS <-> RESEARCHING <-> BLOCKED -> READY_FOR_APPROVAL -> BASELINED -> IMPLEMENTING -> INTEGRATING -> VERIFYING <-> REWORK -> IN_REVIEW <-> REWORK -> ACCEPTED -> GREEN -> CLOSED`

`CANCELLED` is a valid terminal state when cancellation is authorized and required cleanup is complete.

Key rules:

- `READINESS -> IMPLEMENTING` is illegal. A baseline must exist first.
- Research is conditional, not a mandatory linear stage.
- `REWORK` may return to implementation when the fix stays inside the approved baseline. Material or fundamental deviation must be governed before continuing.
- `GREEN` means the delivered change is technically stable under the required verification. `CLOSED` additionally means status, evidence, worktree/process cleanup, and artifact lifecycle are settled.

### Baseline and implementation transitions by profile

**When G3 is required** (always P2/P3 and any P1 case governance marks gated):

`READINESS/RESEARCHING -> READY_FOR_APPROVAL -> [valid G3] -> BASELINED -> IMPLEMENTING`

The approved baseline must be the exact package reviewed at G3; do not approve an abstract plan and generate a materially different plan afterward.

**When G3 is not required** (P0 and eligible P1):

`READINESS -> [governance confirms gate-free path] -> BASELINED -> IMPLEMENTING`

The baseline may be a lightweight non-file execution context containing at least objective, scope, do-not-touch boundaries, expected change, and verification. “No G3” never means “no baseline.” Any separate controlled-artifact mutation still requires its applicable gate.

### Acceptance and Green transitions

- If G5 is required by profile/project rules, `IN_REVIEW -> ACCEPTED` requires valid G5.
- If G5 is not required, governance may transition `IN_REVIEW -> ACCEPTED` once all required verification/review evidence is complete and no blocker remains; no invented approval is needed.
- `ACCEPTED -> GREEN` occurs after the accepted change is integrated/stable under the defined verification and required mechanical state synchronization is complete.
- `GREEN -> CLOSED` occurs after required evidence/artifact retention and worktree/process cleanup are complete.

## Change class

Change class measures the structural scope of impact, not lines changed.

- `C0 Trivial`: no behavior, interface, data, architecture, or dependency change.
- `C1 Local`: local behavior changes with clear boundaries; no public contract or architecture change.
- `C2 Module`: meaningful capability change within one module; may add internal components, dependencies, or internal interfaces.
- `C3 System`: cross-module contract, system-level data/control flow, or architectural-boundary change.
- `C4 Fundamental`: core architectural assumption, system boundary, or major/irreversible migration change.

## Risk level

Evaluate at least: functional, data, financial, security, operational, compatibility, recoverability.

- `R0 Negligible`: no meaningful operational consequence.
- `R1 Low`: local, easy to detect, easy to recover.
- `R2 Moderate`: real functional impact, but limited, testable, and recoverable without major financial/data/security consequence.
- `R3 High`: cross-module propagation, consequential data correctness, production availability, complex concurrency, difficult detection, difficult rollback, or material advisory/analysis error whose effect is indirect and still requires a human decision before action.
- `R4 Critical`: failure can directly cause or authorize financial action/loss, erroneous automated trading/execution, bypass a core risk control, compromise credentials/critical authorization, feed an automated execution path as an authoritative signal without an independent safety gate, or irreversibly corrupt important data.

Use the **maximum-risk principle**: one genuine R4 dimension makes overall risk R4.

### Financial-risk guardrail

Do not classify work as R4 merely because the project is financial, crypto-related, or a human may use displayed analysis to inform a decision. Advisory/display/analysis features are normally assessed from concrete data, operational, and decision-quality consequences and may be R2 or R3. Escalate to R4 when the system itself can directly cause/authorize financial action, bypass controls, or produce machine-actionable output that an automated execution path consumes without an independent control gate.

## Governance profile

Resolve profile from change class and risk. Use these profiles as execution intensity, not as business severity labels.

- `P0 FAST`: trivial or low-risk local work. Minimal readiness; focused verification; no mandatory G3/G5 unless a controlled mutation is involved.
- `P1 STANDARD`: ordinary local/module work with moderate risk. Lightweight or full readiness as needed; research and human gates are conditional.
- `P2 STRICT`: system change or high-risk work. Full readiness, explicit G3, controlled baseline, strong verification, independent review, and G5.
- `P3 CRITICAL`: any R4 work. Mandatory research when relevant to the decision, failure/recovery analysis, explicit G3/G4/G5, independent verification and review, and conservative parallelization.

If a nominal `C0` claim carries high/critical risk, re-check the change classification rather than trusting the combination.

## Baseline deviation

- `D0 Incidental`: implementation detail only; scope, contract, architecture, and risk remain unchanged. Continue without G4.
- `D1 Material`: important implementation-plan change such as a new dependency, meaningful internal interface shift, wider module impact, persistence change, or material verification change. Produce a change proposal; P2/P3 normally require G4.
- `D2 Fundamental`: scope expansion, architecture/public-contract change, risk escalation to R4, or irreversible migration. Stop the affected work, require G4, and normally return to readiness after approval.

## Reclassification

Other GAD skills may recommend reclassification and provide evidence. `gad-governance` finalizes and persists C/R/P. New evidence may escalate class, risk, or profile immediately. A high-governance downgrade must cite evidence and must not be performed merely to avoid process.
