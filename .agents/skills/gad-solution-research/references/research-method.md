# Research Method

## Research Brief contract

Do not begin unbounded research without:

- problem
- decision needed
- current architecture/implementation context
- constraints
- compatibility requirements
- governance/risk context
- explicit questions
- out-of-scope topics
- owning skill/decision flow to return to

When a delivery batch already has a finalized P0-P3 profile, include it. For architecture-stage research before a batch profile exists, a provisional risk/governance context is sufficient; do not invent a delivery profile.

Return `RESEARCH BLOCKED` when missing context materially changes what “fit” means.

## Research order

1. internal project implementation and prior decisions
2. existing dependencies/utilities/platform capabilities
3. official docs, SDKs, reference architecture, migration/security guidance
4. mature maintained libraries
5. mature open-source systems for patterns and operating experience
6. maintainer issues/discussions and broader community experience
7. secondary articles only for discovery/context, not as the sole basis for critical claims

## Hard mutation boundary

Research is read-only. The following are always outside the research role:

- package/dependency installation or removal
- source/configuration changes
- migrations or infrastructure changes
- architecture mutation
- production or exploratory implementation
- credentials/secrets setup
- implementation worker launch

If the user requests any of these after or during research, do not execute them. Return an `IMPLEMENTATION HANDOFF` to the owning readiness/governance flow. A direct user instruction to install or modify does not replace the required implementation baseline/gate.

## Decision sufficiency

Stop research when:

- major viable candidates are covered
- critical questions have credible evidence
- important failure modes/limitations are understood
- another search round is unlikely to change the decision materially

Do not attempt exhaustive internet coverage.

## Profile-sensitive depth

- **P0:** research normally skipped.
- **P1:** lightweight research only when useful.
- **P2:** deeper research for unfamiliar/architectural/dependency choices.
- **P3:** require strong primary evidence, failure modes, and recovery/safety implications relevant to the decision.

For pre-delivery architecture research without a finalized profile, use the risk/governance context supplied by governance and scale depth to the reversibility and consequence of the decision.

## PoC boundary

Research is read-only. If evidence cannot answer a decision and an experiment is genuinely necessary, return `POC REQUIRED` with:

- hypothesis/question to prove
- minimal experiment scope
- expected evidence
- mutation/resources required
- cleanup requirements
- risks

A PoC is a separate governed exploratory batch; never silently install/build it during research.

## Return-to-owner contract

Research Findings must return to the owning skill with:

- decision addressed
- findings/evidence
- recommendation
- uncertainties
- conditions that would change the recommendation
- new risk/classification evidence, if any
- PoC requirement, if any

The owning skill integrates project constraints and makes the architecture/implementation decision. `gad-governance` finalizes any C/R/P change.

## Research Findings schema

1. Research question
2. Decision context
3. Constraints
4. Internal reuse findings
5. Official solutions
6. External candidates
7. Relevant OSS patterns
8. Known failure modes/pitfalls
9. Candidate comparison
10. Build / Adopt / Adapt analysis
11. Recommendation for owning skill
12. Evidence and source quality
13. Uncertainties
14. Further research / PoC needed
