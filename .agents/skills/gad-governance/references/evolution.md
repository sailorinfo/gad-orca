# GAD Skill Evolution

All `gad-*` skills may observe and propose their own improvement, but no `gad-*` skill may modify itself or another GAD skill without explicit G4 approval.

## Allowed without approval

A GAD skill may:

- observe a weakness or repeated workaround
- collect evidence
- analyze root cause
- record a temporary evolution candidate
- prepare an evolution proposal
- prepare a suggested diff for review

It may not mutate `SKILL.md`, `references/`, triggers, human gates, or the GAD skill map.

## Evolution triggers

Raise an evolution candidate only when at least one applies:

- `E1 User Correction`: the user identifies incorrect skill behavior.
- `E2 Repeated Workaround`: the same workaround appears repeatedly.
- `E3 Missing Case`: a legitimate recurring scenario is not handled.
- `E4 Rule Conflict`: rules conflict internally or with GAD governance.
- `E5 Inefficiency`: the skill imposes recurring unnecessary process cost.
- `E6 Quality Failure`: a workflow defect contributed to a missed issue or bad outcome.
- `E7 Capability Shift`: a new tool/platform capability makes the old workflow materially obsolete.
- `E8 Explicit Evolution Request`: the user asks to optimize the skill.

Do not run a self-improvement ritual after every successful use.

## Root-cause test

Before proposing any permanent rule change, first determine whether the current approved rule already prohibited or handled the observed behavior.

- If the current rule was sufficient and the agent failed to follow it, classify the event as `execution non-compliance`. Correct and revalidate behavior; do not evolve the rule to legitimize the violation.
- If the current rule is genuinely missing, ambiguous, contradictory, or insufficient for a legitimate recurring case, continue to the generalization test below.

A failed execution is evidence for evolution only when the failure reveals a rule defect rather than merely non-compliance with an adequate rule.

## Generalization test

Before proposing a GAD-core mutation, classify the finding:

- one-off task fact -> keep in task evidence or do not persist
- project-specific invariant -> project rules or project documentation
- domain-wide reusable knowledge -> domain skill candidate
- cross-project GAD rule -> GAD skill evolution candidate

Only the final category should normally modify a GAD core skill.

## Change types

- `S0 Clarification`: wording/precision without intended behavioral change.
- `S1 Extension`: adds a missing supported case without changing the core contract.
- `S2 Behavioral Change`: changes how the same input is handled.
- `S3 Governance Change`: changes gates, permissions, states, risk/classification, baseline semantics, or the GAD skill map.

Every formal mutation requires G4. S3 requires especially explicit review.

## Evolution proposal contract

A proposal must state:

- skill
- change type
- observed problem
- evidence and frequency
- current behavior
- proposed behavior
- why existing rules are insufficient
- generalization scope
- affected files
- benefits
- added complexity/cost
- potential regressions
- alternatives
- over-design assessment
- validation plan
- rollback plan

Then stop and wait for G4.

## Anti-bloat rules

Before adding a permanent rule, ask:

- Is this recurring or one-off?
- Is this truly this skill's responsibility?
- Can the existing rule already cover it?
- Is a project/domain rule more appropriate?
- Does it belong in the kernel, a conditional reference, or only an example?
- Can a smaller edit solve the problem?

Prefer the minimum necessary diff.

## Validation after approval

After an approved mutation:

1. apply the minimal scoped change
2. run static validation of skill structure and references
3. reproduce the motivating scenario
4. run at least one ordinary regression case
5. run at least one case where the new rule should *not* trigger
6. accept the new baseline only if behavior improves without unacceptable regression

If validation fails, restore the last approved version and prepare a new proposal rather than silently patching the failed change.

Existing baselined delivery batches continue under the governance baseline they were approved against unless a separate governed migration decision is made. New skill behavior applies prospectively by default.
