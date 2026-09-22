# Capability Allocation and Parallelization

## Least-complexity allocation

For every capability, prefer the least-complex mechanism that satisfies the requirement.

- **Program** — deterministic calculation, rule, algorithm, internal transformation, or ordinary business logic.
- **Tool** — deterministic capability that an agent genuinely needs to invoke as an action.
- **MCP** — standardized boundary to an external system, service, data source, or externally hosted capability when that abstraction is useful.
- **Skill** — reusable knowledge, decision method, workflow, or professional reasoning procedure that is not merely a deterministic algorithm.
- **Agent** — role requiring autonomous/non-deterministic reasoning, iterative tool use, or dynamic next-step decisions within a clear responsibility boundary.
- **Orchestration** — supervised coordination of multiple independently ownable tasks/roles, including waiting, messaging, decision gates, or DAG dependencies.

Ask in increasing complexity: can Program solve it? If not, Tool? External boundary/MCP? Reusable reasoning/Skill? Autonomous role/Agent? Multi-role coordination/Orchestration?

Do not create an Agent for a fixed input-to-output transform. Do not create a Skill for a mathematical calculation. Do not expose an internal function as a Tool unless an agent actually needs to invoke it.

## Skill candidate test

A capability is a stronger Skill candidate when it:

- contains a reusable method/decision process
- will be applied repeatedly across tasks or agents
- depends on contextual judgment rather than only deterministic computation
- benefits from progressive guidance/references

Project-specific invariants may belong in project rules instead of a reusable GAD/domain skill.

## Agent candidate test

Use an Agent only when several are true:

- non-deterministic reasoning is required
- intermediate results change the next action
- multiple tools/data sources must be chosen dynamically
- multi-turn context or role responsibility matters
- a stable autonomous boundary can be stated

## Parallelization gate

Choose execution mode from task independence, modification overlap, shared mutable state, dependency depth, integration cost, and risk.

- **Single Agent:** small, concentrated, highly coupled work.
- **Parallel read-only subagents:** independent research/review/analysis over shared state without mutation.
- **Parallel Orca worktree workers:** low-coupling code changes with separate ownership and manageable integration.
- **Structured Orca orchestration:** supervised DAGs, ask/reply, decision gates, or multi-worker lifecycle coordination.

Do not parallelize merely because Orca supports workers.

For P3/critical work, prefer role separation (implementer -> independent verifier -> independent reviewer) over several workers concurrently editing the same critical core.

## Worker handoff contract

When workers are used, each task should name:

- target
- concrete change/result
- constraints and do-not-touch boundaries
- ownership/edit scope
- observable acceptance evidence

Use the approved execution baseline as the common source of truth rather than forwarding a long informal chat transcript.
