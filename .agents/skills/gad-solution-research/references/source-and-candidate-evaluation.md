# Source Quality and Candidate Evaluation

## Evidence priority

Prefer, in order:

1. observable project facts / existing controlled decisions
2. official documentation, SDKs, standards, maintainer guidance
3. primary source code and release history
4. maintained mature OSS/library evidence
5. maintainer issues/discussions and credible operational experience
6. broader community discussion
7. secondary articles
8. model inference

Label inference and unknowns explicitly. For time-sensitive technologies, verify current version/release/maintenance status.

## Candidate dimensions

Evaluate only dimensions material to the decision, typically:

- requirement fit
- architecture fit
- maturity and API stability
- maintenance/release health
- reliability/failure behavior
- security posture
- performance/scalability where relevant
- integration cost
- operational cost
- dependency footprint
- migration cost
- lock-in / exit cost
- license implications
- ecosystem/documentation quality

Prefer qualitative evidence such as `Strong / Acceptable / Weak / Unknown` over fake numerical precision.

## Mature OSS/library checks

Do not equate stars with maturity. Inspect, as relevant:

- recent commits/releases
- issue handling and unresolved critical issues
- maintainer activity
- compatibility matrix
- documentation/examples
- test quality / CI signals
- license
- dependency/security burden

When direct code reuse is considered, distinguish borrowing an architectural pattern from copying licensed source code.

## Adversarial check

For leading candidates ask:

- When should we *not* use this?
- What assumptions can fail in our project?
- What production pitfalls are repeatedly reported?
- How difficult is replacement later?
- Which constraint would invalidate the recommendation?

## Build / Adopt / Adapt

- **Build:** project-specific/simple logic, need for control, or external options add more cost/risk than value.
- **Adopt:** standardized problem with a mature option that fits current architecture and operational constraints.
- **Adapt:** reuse a mature option behind a project-owned boundary/adapter to preserve compatibility and replaceability.

Research may recommend a direction, but the owning skill integrates project constraints and makes the final proposal.
