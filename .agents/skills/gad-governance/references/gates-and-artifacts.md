# GAD Human Gates and Artifact Governance

Use this reference for approval semantics, controlled mutations, artifact ownership/lifecycle, retention, promotion, source-of-truth, handoff, and cleanup.

## Standard human gates

Only these five gate types exist in GAD v1:

- `G1 Project Definition Approval`: approves the formal project definition and authorizes `PROJECT.md`.
- `G2 Project Baseline Approval`: approves the exact combined high-level architecture and project-governance baseline package, including approved ADRs.
- `G3 Execution Baseline Approval`: approves the actual execution-baseline draft for a delivery batch and authorizes implementation within that scope.
- `G4 Controlled Change Approval`: approves a material/fundamental deviation or mutation to controlled artifacts, including `gad-*` skills.
- `G5 Integration / Acceptance Approval`: accepts a governed delivery batch for formal integration when the active governance profile or project rules require it.

## Approval semantics

Approval must be explicit and scoped. Examples that can authorize a gate when clearly bound to the active proposal: `批准`, `确认`, `按此执行`, `可以固化`, `允许修改`, `APPROVE`, `Proceed with this plan`.

Do not treat these as approval on their own: `不错`, `方向可以`, `继续`, `有道理`, `差不多`, `可以考虑`.

Non-rejection is not confirmation. Supplying requested facts or clarifications is not approval. Completing missing information does not authorize implementation, integration, controlled-artifact mutation, or any other gated action; resume the workflow from the correct state and gate after clarification.

An approval must identify or unambiguously refer to:

- gate type
- target project/batch/artifact
- proposal or baseline identity
- authorized actions

Approval is not permanent. A D2 deviation, significant scope change, material risk escalation, or relevant architecture-baseline change invalidates any approval that depended on the prior facts.

Conversation recap/summary text is never an approval record. If it claims an approval or state transition that is not supported by the explicit approval and governed artifacts, ignore the recap claim and report the conflict.

## Source-of-truth and permission channels

For baseline semantics, approved A1 artifacts are authoritative. `PROJECT_STATUS.md` is the governed operational record of current state and should reflect already-authorized facts. Current repository/runtime facts may reveal drift but do not silently rewrite the baseline.

A2 working artifacts, chat discussion, and conversation recap are never authoritative baselines.

Permission is separate from factual authority: only an applicable explicit scoped gate approval (or a mechanical action package already authorized by that gate) permits a gated mutation/action.

## Cross-skill handoff contract

When ownership changes, the current skill must hand off with:

- `from_skill`
- `next_owner`
- `output_or_evidence`
- `decision_needed`
- `current_state`
- `required_gate`
- `blockers`, if any

A handoff ends the current skill's substantive role. The same agent/session may continue only after explicitly loading/invoking the next owner's skill contract. Do not perform the next owner's work under the previous skill's authority.

## G2 package composition and ownership

The G2 Project Baseline package is combined, but ownership remains split:

- `gad-system-architecture` owns the Architecture Proposal and ADR candidates.
- `gad-governance` owns the Governance Baseline Proposal covering `PROJECT_RULES.md`, `DEVELOPMENT_WORKFLOW.md`, lifecycle/gate application, and the project-state transition package.
- `gad-governance` consolidates the exact G2 package and presents the gate request.

`gad-system-architecture` may identify architecture-implied governance constraints, but it must not author or semantically mutate `PROJECT_RULES.md`, `DEVELOPMENT_WORKFLOW.md`, or `PROJECT_STATUS.md` on behalf of governance.

After valid G2, the approved artifacts are promoted under their lifecycle owners and the project transition completes through `BASELINED` to `ACTIVE`.

## Artifact classes

- `A1 Baseline`: approved source of truth. Controlled mutation only.
- `A2 Working`: drafts, proposals, analysis, and task-working material. Not authoritative.
- `A3 Evidence`: records what actually happened: verification, review, integration, benchmark, operational evidence.
- `A4 Ephemeral`: scratch notes, transient analysis, worker handoff material, caches, and temporary outputs. Never source of truth.

## Long-lived project artifacts and owners

- `PROJECT.md` — owner: `gad-project-inception`; create via G1; later semantic mutation via G4.
- `ARCHITECTURE.md` — owner: `gad-system-architecture`; create via G2; later mutation via G4.
- `PROJECT_RULES.md` — owner: `gad-governance`; create via G2; mutation via G4.
- `DEVELOPMENT_WORKFLOW.md` — owner: `gad-governance`; create via G2; mutation via G4.
- `PROJECT_STATUS.md` — owner: `gad-governance`; derived state record. Mechanical synchronization of already-authorized facts does not need a second gate.
- `decisions/ADR-*.md` — owner: `gad-system-architecture`; create under the G2/G4 decision that authorizes the architecture decision.

Ownership is semantic, not necessarily a restriction on which process performs a byte-for-byte promotion. A coordinator may mechanically promote the exact approved content for another owner only when the gate's authorized action package explicitly permits that promotion and no semantic edits are introduced.

## Delivery-batch artifacts and owners

- `REQUIREMENTS.md` — owner: `gad-implementation-readiness`.
- `RESEARCH.md` — owner: `gad-solution-research`; persist only when governance/profile justifies retention.
- `EXECUTION_PLAN.md` — owner: `gad-implementation-readiness`; may use `writing-plans` to produce the draft.
- `VERIFICATION_PLAN.md` — owner: `gad-implementation-readiness`.
- `RESULT.md` — lifecycle owner: `gad-governance`; content may include verification, review, integration, and operational evidence from other skills/tools.

For P0 and some P1 work, a lightweight non-file execution baseline is valid if it records at least: objective, scope, do-not-touch boundaries, expected change, and verification.

## Promotion and mutation

A working artifact becomes baseline only after the gate that authorizes its exact content, or through a governance-approved gate-free lightweight-baseline path where G3 is not required. Do not create the formal baseline first and seek approval afterward.

For retained research in a gated batch, the G3 package must identify the exact research draft and retention decision. After G3, `gad-solution-research` remains semantic owner of `RESEARCH.md`; a coordinator may perform an exact mechanical promotion if that action was included in the approval package.

Temporary or working material may live in `.gad/temp/` if the project permits it. Such material:

- is not authoritative
- must not contain secrets
- must not be required as a permanent dependency by a GAD skill
- should be cleaned when its batch closes or when its information has been promoted into controlled artifacts

Creating a controlled artifact for the first time is still a controlled mutation unless the applicable profile explicitly uses a non-file lightweight baseline.

## Retention and cleanup

- Project baselines and important ADRs: retain for the project lifetime; use Git history for versions rather than `-v2` filenames.
- P0: normally no task documents.
- P1: retain only what is useful; working drafts should normally be removed after closure.
- P2: normally retain requirements, execution plan, verification plan, and result. Retain research when it materially influenced the decision.
- P3: retain requirements, research, execution plan, verification plan, result, relevant ADRs, and critical evidence needed for auditability.
- Evidence for high/critical-risk work should normally be retained.
- Baseline artifacts are archived/superseded rather than silently deleted.

If a batch is cancelled after it was baselined or implementation began, record the cancellation outcome and cleanup rather than silently removing the history.

## Authorization inheritance

A gate may authorize a clearly stated action package, e.g. G5 may authorize integration, mechanical `PROJECT_STATUS.md` synchronization, `RESULT.md` finalization, and predefined cleanup. Do not ask for duplicate confirmation for mechanical consequences already named in the approved gate request.
