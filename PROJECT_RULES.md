# PROJECT RULES — gad-orca

## 1. Authority and project state

The user owns product direction, high-risk decisions, and explicit scoped G1–G5 approvals. GAD Lead is the sole daily communication gateway between the user and specialist Workers. Workers report to Lead; they do not solicit Gate approval from the user. Lead coordinates, reconciles, reflects, verifies evidence, and prepares decision packages; it does not edit project files, implement product work, independently review its own dispatch, integrate without authorization, or approve a Gate.

The project lifecycle is `IDEA → DEFINING → DEFINED → ARCHITECTING → BASELINED → ACTIVE → MAINTENANCE → RETIRED`. G1 establishes `DEFINED` and formal `PROJECT.md`. G2 approves the exact combined architecture and governance baseline. After approval and exact promotion, Governance synchronizes `ARCHITECTING → BASELINED → ACTIVE`; `BASELINED` is transitional, not a steady parking state. A project state change records an authorized fact; it does not create a product Delivery Batch.

## 2. Source of truth and permission

For project facts, use approved mainline baselines first, then governed mainline `PROJECT_STATUS.md`, Git facts, Orca runtime facts, Worker/review evidence, A2 material, Lead working notes, and conversation recaps. A Worker branch's status is a historical snapshot. Conflicts that affect a decision must be exposed and resolved before the dependent action. Runtime facts may reveal drift but do not silently rewrite an approved baseline.

Permission is distinct from factual authority. Only a valid explicit approval for the applicable Gate and exact target, or a mechanical action package already authorized by that approval, permits a gated action. Silence, positive discussion, an A2 draft, a test result, or a clarification is not approval. A material change to the approved target or its risk can invalidate the approval.

## 3. Artifact ownership and Gates

`PROJECT.md` is owned by Inception and created through G1. `ARCHITECTURE.md` and any approved ADRs are owned by Architecture and created through G2. `PROJECT_RULES.md`, `DEVELOPMENT_WORKFLOW.md`, and derived `PROJECT_STATUS.md` are owned by Governance. Semantic changes to approved project baselines use G4 and the owning skill. Mechanical synchronization of already-authorized status facts does not require a second Gate. A2 proposals are never formal baselines. Formal artifacts are promoted only after approval of their exact content; important baselines and evidence remain traceable through Git.

G1 approves the project definition; G2 approves the exact Architecture/Governance Project Baseline; G3 approves a bounded Batch execution baseline when required; G4 approves controlled material or fundamental deviations and protected artifact changes; G5 accepts a Batch for integration when required by its profile or rules. Lead packages decisions but cannot approve them. G2 does not authorize G3, any product Batch, implementation, acceptance, integration, release, or edits to the GAD Skills or Lead package.

## 4. Proportional governance

Governance classifies each bounded change by structural scope `C0–C4` and maximum concrete failure consequence `R0–R4`, then selects `P0–P3`. Financial-domain context alone is not R4. P0 and eligible P1 work may use a governance-confirmed lightweight execution baseline without G3, recording at least objective, scope, do-not-touch boundaries, expected change, and verification. P2/P3 require full readiness, explicit G3, strong verification, independent review, and G5. A controlled artifact still requires its applicable Gate regardless of profile. New evidence may escalate classification; material or fundamental baseline deviation is governed before affected execution continues.

The G2 project-baseline decision was assessed `C3 System / R3 High / P2 STRICT` because cross-module control and approval rules can propagate errors. This classification applies only to that G2 decision and does not pre-classify future product Batches.

## 5. Lead modes and execution boundary

Shadow Mode is read-only. Bootstrap Mode permits only project inception, architecture, governance baseline preparation, and formal Lead adoption coordination. Active Mode requires a valid exact G2 approval, exact promotion of this formal governance baseline, and mainline verification of the following marker:

GAD Lead Active Mode: APPROVED

The marker in an A2 draft has no effect. Once formal and effective, it permits Lead to coordinate ordinary delivery only within each separately authorized Batch and Gate boundary. It does not grant product implementation or Gate approval. Orca remains the sole Orchestrator for Worktree, Terminal, Agent launch, and session primitives; Lead does not create a second scheduler or private project-state authority.
