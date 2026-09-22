---
name: gad-solution-research
description: Use when architecture or implementation planning needs read-only evidence about internal reuse, official solutions, mature libraries, open-source patterns, known failure modes, or Build/Adopt/Adapt options. It must not install, modify, implement, or make the final project decision.
---

# GAD Solution Research

## Purpose

Gather sufficient engineering evidence for a bounded architecture or implementation decision. Determine what already exists internally and externally, how mature options behave in practice, and what Build / Adopt / Adapt choices are plausible. Return evidence to the owning skill; do not make the final project decision or implement it.

Apply `gad-governance` for research permission, governance/risk context, artifact permissions, handoff, and any PoC/controlled-mutation decision.

## Trigger

Run only from a clear Research Brief supplied by `gad-system-architecture`, `gad-implementation-readiness`, or an explicit user request that contains an equivalent bounded decision brief. Research is conditional; do not start broad external investigation simply because a topic is interesting.

## Mandatory context

Require a Research Brief with: problem, decision needed, current context, constraints, compatibility requirements, governance/risk context, questions to answer, out-of-scope topics, and the owning skill/decision flow to return to.

A finalized delivery P0-P3 profile is required only when a delivery batch already has one. Architecture-stage research before a delivery profile exists may use provisional risk/governance context supplied by governance; do not invent a batch profile merely to satisfy the brief.

For project-related research, read relevant `PROJECT.md`, `PROJECT_RULES.md`, architecture sections, existing dependencies, and related implementation as needed so research is evaluated against the actual project rather than generic popularity.

## Core workflow

1. Validate the Research Brief and stop if the decision target is unclear.
2. Check internal reuse and current dependencies first.
3. Check official documentation/SDK/reference architecture.
4. Evaluate mature libraries and maintained open-source implementations only as needed.
5. Inspect issues/discussions/real failure experience for important candidates.
6. Compare fit, limitations, integration/operational/migration cost, lock-in, and evidence quality.
7. Perform an adversarial check on leading candidates.
8. Produce Build / Adopt / Adapt analysis and return Research Findings to the owning skill.
9. Stop when evidence is sufficient for the decision; do not optimize for exhaustive search.

Load `references/research-method.md` for the bounded research process, hard mutation boundary, stopping rules, PoC boundary, and output structure.
Load `references/source-and-candidate-evaluation.md` for source priority, library/OSS evaluation, evidence quality, failure-mode checks, and Build/Adopt/Adapt comparison.

## Hard read-only boundary

Research has no implementation authority, even when the user says “just install it,” “modify the project now,” or otherwise asks to continue directly from the recommendation.

When an install/config/code/migration/PoC request appears:

1. do not perform the mutation
2. preserve the Research Findings
3. identify the owning implementation/architecture flow
4. hand off to `gad-implementation-readiness` or `gad-governance` as appropriate
5. require the normal baseline/gate path before implementation

The same agent/session may continue only after explicitly leaving the research role and loading/invoking the next owner's skill contract. Research itself must never execute the mutation.

## Never

- Do not install candidate packages, modify source/configuration, run migrations, create credentials, change architecture, launch implementation workers, or create a production PoC under the guise of research.
- Do not treat an explicit implementation request as permission to cross the research boundary.
- Do not treat GitHub stars, a single blog, or a single model inference as sufficient evidence for a high-risk choice.
- Do not hide unknowns; mark them explicitly.
- Do not convert Research Findings into the final architecture/implementation decision. Return to the owning skill.
- Do not create formal `RESEARCH.md` before the governing retention/promotion decision authorizes it.
- Do not finalize C/R/P; use governance-provided context and return new risk evidence to `gad-governance`.

## Output contract

Return `RESEARCH FINDINGS` containing the research question/context/constraints, internal reuse, official options, external candidates/patterns, known failure modes, candidate comparison, Build/Adopt/Adapt analysis, recommendation to the owning skill, evidence/source quality, uncertainties, and whether further research or a separately governed PoC is needed.

If the user asks research to implement, also return an `IMPLEMENTATION HANDOFF` naming the next owner and stating that no implementation authority was granted by research completion.

## Exit / handoff

Normal exits are `RESEARCH COMPLETE`, `POC REQUIRED`, or `RESEARCH INCONCLUSIVE`. Return findings to the owning `gad-system-architecture` or `gad-implementation-readiness` flow. Research completion does not authorize implementation.

For retained research, this skill is semantic owner of the research artifact. Promotion to formal `RESEARCH.md` occurs only under the applicable approved retention/action package; a coordinator may mechanically promote exact approved content without semantic edits when authorized.

A role boundary is a hard stop: the same agent/session may continue only after explicitly loading/invoking the next owner's skill contract.

Skill evolution is proposal-only and follows `gad-governance`; never self-modify.
