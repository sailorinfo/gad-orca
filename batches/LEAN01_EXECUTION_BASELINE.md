# A2 — LEAN-01 Runtime & Lifecycle exact G3 proposal

Status: READY_FOR_APPROVAL draft, not an execution baseline. Project gad-orca ACTIVE. Mainline base: `f19e2a22bfe13eb8266d982ab66de45a1ef7cf00` (approved G4). The exact proposal commit and Git blob must be named at G3. No implementation, integration or cleanup is authorized by this draft.

## Requirements and scope

Deliver one usable ordinary-Batch Lean lifecycle path: REUSE_BEFORE_CREATE, a counted Worktree/Worker/Branch budget, independent review of a frozen implementation commit, deterministic authorized mechanical actions, guarded evidence lifecycle, recovery after interruption, and a quantified closing report. Preserve Human Gates, artifact owners, independent review and durable evidence.

Non-scope: LEAN-02 four-level governance, LEAN-03 Gate Advisor, LEAN-04 installer/upgrade, GAD Skill mutation, second Orca Orchestrator, cross-platform abstraction, new scheduler/database, automatic Gate approval, and remote push/deletion without separate scope. G3 does not authorize changes to PROJECT.md, ARCHITECTURE.md, PROJECT_RULES.md or DEVELOPMENT_WORKFLOW.md. Governance semantics beyond approved G4 require another G4.

Acceptance: no dedicated mechanical Worker; all listed actions fail closed on missing authority, SHA drift, dirty/unknown objects or incomplete evidence; a frozen-commit independent Reviewer reports without modifying implementation; interrupted state is recoverable; final metrics have provenance and an honest comparison to Bootstrap.

## Architecture fit, reuse and Orca evidence

G2 places judgment in Skills/Lead, durable facts in Git/formal baselines, and Worktree/Terminal/Agent execution in Orca. G4-approved project rules now prevail over conflicting Operating Model/README conventions pending this G3 synchronization. Existing `gad-lead/tools/gad-lead.ps1` has Git/Orca invocation, status, doctor and Agent resolution. Existing `gad-lead/tests/bootstrap-matrix.ps1` shows the test style. No new dependency or unfamiliar core technology is needed. Research Gate: FALSE. Architecture clarification: unnecessary unless implementation discovers a need for a new authority store or Orca replacement.

Local Orca CLI evidence, 2026-09-22, is recorded in `LEAN01_ORCA_CAPABILITY_A2.md`: `terminal create --help` offers a new Terminal in an existing Worktree but no read-only/frozen checkout option; `terminal list --worktree active --json` reports the existing agent Terminal `writable: true`. Same-checkout Session isolation cannot be demonstrated. Per approved G4, Review therefore uses the **fourth Worktree**, created from the frozen exact implementation commit, with a fresh Session and no Implementer transcript. Reviewer must not edit implementation; verify review checkout HEAD and cleanliness before/after. A Session-only path may replace it only if Orca later supplies concrete evidence of a frozen read-only boundary before dispatch.

`orca terminal close --terminal <handle> --json` closes a known Terminal. `orca worktree rm --worktree <id> --json` removes a Worktree and may also delete its associated local Branch; it retains branches it knows predated the Worktree or cannot prove merged. Worktree and Branch disposition therefore need exact pre/post ref checks as one observed transaction. `worktree list --repo ... --json` and `terminal list --worktree ... --json` expose identities and live state. Git supplies exact SHA, clean-tree, reachability, fast-forward and remote-ref checks. These are read-only capability observations, not proof that destructive operations have been safely tested.

## Exact change surface and execution plan

Allowed production files: `gad-lead/GAD_LEAD_OPERATING_MODEL.md`, `gad-lead/README.md`, `gad-lead/tools/gad-lead.ps1`, optionally one focused `gad-lead/tools/gad-control.ps1`, `gad-lead/MANIFEST.json` only if tool inventory changes, and `gad-lead/SHA256SUMS.txt` for changed package bytes. Allowed verification files: `gad-lead/tests/lean-lifecycle-matrix.ps1` and minimal fixture data if necessary. Fewer files are acceptable; another production file requires renewed readiness. Do not touch installer/Bootstrap logic or GAD Skills.

1. After explicit G3, promote this exact proposal blob as the Batch execution baseline. Reconcile main/Orca and record starting topology and time; stop on baseline drift.
2. Reuse existing gad-lead. Create one implementation Worktree from exact main base only after REUSE_BEFORE_CREATE. One Implementer owns the allowed files; no parallel code editing. Rework resumes that owner.
3. Align Operating Model/README with approved G4, removing mandatory mechanical Worker and automatic Review Worktree language. Implement a narrow control command in the existing Lead CLI or one focused script. Orca remains the only Worktree/Terminal/Agent executor.
4. Lead checks formal Gate/action-package authorization and exact objects before invocation; tooling independently checks object IDs/hashes and preconditions. A CLI flag or A2 note alone is not Gate proof. Every action emits a machine-readable pre/post snapshot and recoverable failure. Do not use broad reset/clean, force merge, or default force removal.
5. Freeze implementation commit SHA and evidence. Create Review Worktree from that SHA; a fresh Reviewer gets the SHA, baseline and evidence, never Implementer chat. Review is read-only by contract and returns PASS/FAIL against exact SHA. Rework yields a new frozen SHA and fresh independent review. Reuse Review Worktree only after safe state proof; otherwise remove/recreate within four total Worktrees, never create a fifth.
6. Lead reconciles evidence and requests G5. Only G5 authorizes exact integration, status/result sync and specified cleanup. Mechanical actions then run with pre/post checks, without dedicated Workers. Final RESULT records metrics and provenance.

## Deterministic control-plane contract

| Action | Authority and precondition | Postcondition |
| --- | --- | --- |
| Exact baseline promotion | Gate names source blob, target and expected base; target unchanged | Target blob equals approved blob; diff only named files. |
| Mainline integration | G5 names reviewed SHA; clean trees, review/required tests PASS, fast-forward possible | Main HEAD equals SHA; no conflict resolution. |
| Status synchronization | Gate already authorized exact transition; Lead reconciles facts; only named fields change | Commit/diff reflects authorized state only. |
| Terminal close | Exact handle belongs to known completed Worker; output retained; never Lead/unknown | Handle no longer live. |
| Worktree remove/archive | Exact Orca ID and branch SHA; no live dependent Terminal, dirty tree, unique untracked file or unreachable evidence | Re-list topology; Worktree absent or archived; branch disposition recorded. No `--force` by default. |
| Local Branch delete | No Worktree uses it; exact SHA known; evidence reachable; account for Orca rm's possible deletion | Ref absent or retained with reason; no remote deletion. |
| Remote SHA check | Read-only remote/ref identity recorded | Report SHA match/mismatch; no claim of push from local HEAD. |
| Batch closure | G5 package, GREEN evidence, RESULT, retention and object dispositions complete | CLOSED recorded once with metrics/evidence links. |

Absent or mismatched Gate target, changed object, dirty/unknown owner, missing evidence, non-fast-forward, unique unreachable commit or failed postcondition stops the affected action. Partial execution is reported and reconciled, never hidden by speculative cleanup. Durable evidence remains in Git/formal RESULT; archive/delete requires the applicable retention disposition.

## Required Risks → verification → stop conditions

Plan **8 focused cases**. Use at most two small disposable Git repositories at a time; each case may contain several assertions. Classify fixture failures before adding cases.

| Case | Required risk evidence |
| --- | --- |
| V1 | Missing Gate/wrong target refuses promotion or status mutation; original bytes/HEAD remain. |
| V2 | Exact approved promotion/fast-forward succeeds; wrong blob or non-fast-forward refuses. |
| V3 | Dirty/unknown Worktree or live Terminal refuses removal; user files/refs remain. |
| V4 | Clean known Worktree removal records Orca's Branch disposition; unique commit is refused or retained. |
| V5 | Known completed Terminal closes; Lead/unknown handle is refused. |
| V6 | Frozen-commit Review Worktree starts at named SHA, receives no Implementer transcript, returns named SHA, leaves both trees unchanged. |
| V7 | Interrupt/retry reconstructs state without duplicate Worktree/Branch/status transition or false CLOSED. |
| V8 | Ordinary path reports all seven metrics, Bootstrap provenance and zero user manual coordination. |

Stop Test Expansion once V1–V8 and independent Review pass, all required risks have evidence, and no concrete new failure path remains. New cases require a recorded risk/failure rationale and governance check for material verification change. Stop affected execution for an unapproved semantic change, fifth Worktree requirement, lost evidence, failed review isolation or unsafe mechanical primitive. Optional hardening goes to a later Batch.

## Budget, metrics and recovery

Starting topology: main + gad-lead = 2. Planned peak: **4 total Worktrees** (main, gad-lead, implementation, Review); **at most 2 new Branches**; at most **2 concurrent specialist Workers** (Implementer and Reviewer, with Review only after implementation freezes); **0 dedicated mechanical Workers**. Existing Lead is counted separately and both numbers must be reported. No Worker/Worktree for proposal or closure. An over-budget need requires a new scoped decision first.

Final RESULT records peak concurrent specialist Workers, peak total Worktrees, new Branch count, dedicated mechanical Worker count, verification case count, user manual coordination operation count, and wall-clock elapsed time from first G3-authorized dispatch to CLOSED. Gate decisions are separate; manual Worktree creation, prompt/message relay and cleanup commands count as coordination. Record timestamps, Git/Orca snapshots, test output and review identity. Bootstrap RESULT establishes 19 verification cases but not reliable exact values for every other metric; label each comparison measured, reconstructed or unknown. Targets: <=4 Worktrees, <=2 new Branches, 0 mechanical Workers, 8 planned cases, 0 user manual coordination. Time is measured, not guaranteed.

Before integration, stop and retain implementation/review refs on failure. After a tool failure, report partial state and resume from reconciliation, never destructive rollback. After G5 integration, a semantic baseline reversal uses applicable G4. Closure cannot delete the only evidence path.

Alternatives: a writable same-checkout Review Session does not prove independence; a fourth Worktree satisfies the approved fallback. A Worker per mechanical action recreates the observed cost. A daemon, private state store or second Orchestrator adds no value to this Batch. Revisit Session-only Review when Orca offers a demonstrably frozen read-only execution boundary.

## Governance handoff

Classification: C3 System / R3 High / P2 STRICT, due to cross-batch lifecycle authority and cleanup consequences; G3 and G5 required. Prior G4 is complete on main. `from_skill`: gad-implementation-readiness; `next_owner`: gad-governance via existing Lead; `output_or_evidence`: this exact draft, G4 blobs and local Orca CLI observations; `decision_needed`: confirm gate route and present scoped G3; `current_state`: ACTIVE, LEAN-01 READY_FOR_APPROVAL; `required_gate`: G3 before implementation; `blockers`: none. G3 approves only bounded implementation/verification, not G5, integration or cleanup.
