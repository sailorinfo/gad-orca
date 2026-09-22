---
name: gad-project-inception
description: Use when defining a new project's purpose, problem, goals, non-goals, scope, core use cases, constraints, success criteria, assumptions, and open questions before system architecture begins. Do not use it for system architecture, batch implementation design, or coding.
---

# GAD Project Inception

## Purpose

Turn an early project idea into a clear Project Definition Proposal. This skill owns project definition only: what the project is, why it exists, what is in or out of scope, and how success is recognized.

Apply `gad-governance` first for state, permission, authoritative C/R/P when needed, source-of-truth, handoff, and G1 semantics. Do not redefine governance rules here.

## Allowed states

Run in `IDEA` or `DEFINING`. For an existing project, use this skill only when `gad-governance` has classified the request as a project redefinition rather than an ordinary delivery change.

## Mandatory context

Use the user's stated intent, known constraints, and supplied business/system background. For brownfield redefinition, inspect the current `PROJECT.md` if present, `PROJECT_STATUS.md` if present, and enough current behavior to avoid defining a project that contradicts reality.

Separate all findings into confirmed facts, assumptions, and open questions. Never promote a non-rejected assumption into a confirmed fact.

## Core workflow

1. Capture intent and expected outcome.
2. Define the problem and why the current situation is insufficient.
3. Clarify goals and non-goals.
4. Define in-scope and out-of-scope boundaries.
5. Identify core use cases and consumers.
6. Record explicit constraints and success criteria.
7. Record assumptions, known risks, and deferred/open decisions.
8. Run a scope challenge before proposing approval.
9. Produce a Project Definition Proposal and hand it to `gad-governance` for G1.

Load `references/project-definition.md` for the proposal schema and required distinctions.
Load `references/brownfield-and-scope.md` for brownfield inception or scope-challenge guidance.

## Never

- Do not choose detailed architecture, libraries, databases, runtime topology, or implementation mechanisms.
- Do not classify specific capabilities as Program, Tool, MCP, Skill, Agent, or Orchestration.
- Do not create delivery phases, worker plans, or execution task DAGs.
- Do not create or modify production code.
- Do not create or overwrite formal `PROJECT.md` before explicit G1 approval under `gad-governance`.
- Do not treat clarification completion, enthusiasm, or non-rejection as approval.
- Do not finalize C/R/P. If project-definition facts suggest a change/risk posture, label it as evidence or a recommendation and return it to `gad-governance`.
- Do not perform system architecture as a continuation of inception. Handoff and stop the inception role.

## Output contract

Return a `PROJECT DEFINITION PROPOSAL` containing vision, problem statement, target users/consumers, goals, non-goals, scope, core use cases, constraints, success criteria, assumptions, known risks, open/deferred decisions, and scope-challenge findings.

Include any governance-relevant risk/change observations as recommendations, not final classification.

Then hand off to `gad-governance` with the proposal identity and request G1. If the definition cannot be made reliable, return `PROJECT DEFINITION BLOCKED` with the minimum missing decisions.

## Exit / handoff

After valid G1 approval, the exact approved definition may be promoted to `PROJECT.md` under this skill's ownership. `gad-governance` owns the corresponding `PROJECT_STATUS.md` synchronization and legal transition to `DEFINED`. The next substantive owner is `gad-system-architecture`.

A role boundary is a hard stop: do not perform architecture under the inception role. The same agent/session may continue only after explicitly loading/invoking the next owner's skill contract.

Skill evolution is proposal-only and follows `gad-governance`; never self-modify.
