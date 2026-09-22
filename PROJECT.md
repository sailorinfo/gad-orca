# PROJECT — gad-orca

**G1 批准提案:** `gad-orca-g1-2026-09-22-a2-02` @ `49ff1c6d37cb13bd8256124b15d6d2055ca367d8`
**权威起点:** `main` @ `32bf5b531f1929ccf00c76796223bc3b868f5135`
**状态:** 本文件是上述精确 G1 批准的项目定义；v0.1 产品目标与验收条件仍待实际验证。

## 1. 证据边界

| 类别 | 内容 | 来源 |
|---|---|---|
| 用户确认的方向 | 本文第 2–8 节的项目定位、首期用户、v0.1 闭环、环境边界、验证项目及验收目标。 | 用户向 GAD Lead 给出的 1–4 点方向确认及对上述精确提案的 G1 批准 |
| 仓库已有能力 | `gad-lead/` 已包含 Operating Model、README、安装与初始化入口、启动器、PowerShell 工具、Agent Preference、manifest；仓库也有 `gad-governance`、`gad-project-inception`、`gad-system-architecture`、`gad-implementation-readiness`、`gad-solution-research` Skills。 | `gad-lead/`、`.agents/skills/` @ 指定 main commit |
| 仓库现状 | Lead 文档自标 A2 Design / Pilot；当前 `GAD_AGENT_POLICY.conf` 的角色偏好均为 Codex。G1 前主线没有正式 `PROJECT.md`、`PROJECT_RULES.md`、`DEVELOPMENT_WORKFLOW.md`、`PROJECT_STATUS.md` 或 Project Baseline。 | `gad-lead/GAD_LEAD_OPERATING_MODEL.md`、`gad-lead/README.md`、`gad-lead/GAD_AGENT_POLICY.conf`、Git 文件及状态检查 |
| 待验证 | G1 批准的是 v0.1 产品目标与验收条件；不能由文档、现有文件或历史案例推论完整闭环已通过测试、可供第三方复现或已经发布。 | G1 后的实际 E2E、回归、发布证据尚待产生 |

## 2. 项目定位、价值与用户

**愿景：** gad-orca 是运行在 Orca 之上的开源 Governed Agentic Delivery（GAD）治理与自动化交付层，由 GAD 方法论、GAD Skills、GAD Lead 与 Orca 自动化协作能力组成。长期存在的 GAD Lead 承担日常协调；人保留产品方向、Human Gates 与高风险决策。

**首期用户：** 使用 Orca 与 AI Coding Agent 开发软件的个人与小团队。使用者与 Gate 批准者通过 Lead 沟通；专职 Worker 向 Lead 回报。第三方使用者应能够从发布资产自行 clone、安装和复现 v0.1.0。

**核心问题：** 当前多 Agent 交付容易要求人手工创建 Worktree、复制 Prompt、转发 Worker 消息并判断下一步；Baseline 偏离、实现与审查不独立、会话恢复、Review Fail 后 Rework 与变更治理均可能失稳。单纯增加自动化还可能削弱人在关键决策处的权威。产品应减少这些日常协调负担，同时使状态、证据、职责隔离和批准边界可检查。

## 3. 目标与非目标

**v0.1 目标：** 产品化并验证从 `IDEA → 定义 → 架构 → 实现 → Review → Acceptance → Integration → CLOSED` 的核心闭环，包括 Inception、Architecture、Research、Readiness、Implementation、Independent Review、Rework、G4、G1–G5、Acceptance、Integration、Close，以及状态恢复、证据核验、Worker 编排和 Human Authority。GAD Lead 负责 `RECONCILE → REFLECT → DECIDE` 后的合法协调动作；实际是否达到闭环以第 7 节验收证据为准。

**非目标：** 新的通用 Agent Framework、多个 Orchestrator、模型评分或复杂路由、云端控制平面、多租户、未经证明需要的长期后台服务、重写 Orca、未经验证的跨平台抽象；也不把 Human Gate、方向和高风险决策自动化。原则是 **Extensible, not speculative**。

## 4. 范围与职责边界

**gad-orca 范围内：** GAD 方法论与 Skills 对生命周期及 Inception、Architecture、Research、Readiness、Implementation、Independent Review、Rework、G4、G1–G5、Acceptance、Integration、Close 的治理；GAD Lead 的状态恢复、证据核验、Worker 编排与 Human Gate 决策包；Bootstrap/Init、Shadow/Bootstrap/Active、Worktree Decision、Worker Contract、Agent Preference、doctor/status/recovery 的产品化闭环。

**Orca 的既有职责：** Git Worktree、Terminal、Agent 启动、Worker 隔离与基础编排。Orca 是唯一正式 Orchestrator；gad-orca 在其上定义治理及交付流程，不重写 Orca，也不提前设计 Adapter Framework。

**范围控制：** 上述是 v0.1 产品边界及验收范围，并非声称当前仓库的每条路径均已实现或通过测试。更细的系统边界和实现选择留待 G2/G3 的责任技能，不在 G1 锁定。

## 5. 核心用例

1. **从空项目启动：** 用户在空或新 Git 仓库安装/初始化；即使空 clone 无 root commit，也能进入 Bootstrap，由 Lead 建立工作入口并准备 G1/G2 决策材料。
2. **日常协调及恢复：** Lead 从 Git、Baseline、`PROJECT_STATUS.md` 和 Orca 事实恢复状态，作出下一合法决定，在授权内自动 dispatch、wait、verify 并继续，不依赖聊天记忆。
3. **受控交付与失败路径：** Implementation 与 Independent Review 在独立 Worktree/Session 工作；Review Fail 触发 Rework 路径，Baseline 变化进入 G4；用户在 G1–G5 保留批准权。
4. **完成与复用：** 经 Acceptance、Integration 到 CLOSED；发布的版本与安装材料使第三方可以 clone、install、reproduce。

## 6. v0.1 环境和约束

- 目标环境：Windows 10/11、PowerShell、Git、Orca、GAD Skills、Codex。
- 当前所有角色统一 Codex 是资源条件，不是 GAD 方法论限制。Claude 可兼容并可在后续用于交叉 Review，但不阻断 v0.1 发布；即使同模型，Implementation 与 Independent Review 仍须独立 Worktree/Session。
- v0.1 不承诺 macOS、Linux、WSL 或非 Orca 环境。未来扩展边界保持适度清晰，不提前建立跨平台适配框架。
- G1–G5、方向与高风险决定由用户承担。Lead 不能自批 Gate，普通 Worker 不直接向用户索取批准；这些人工决策不是要消除的协调负担。
- 主验证项目是 gad-orca 自身：从空 GitHub 仓库 dogfood 开发治理并发布 GAD Lead。`crypto-trading-workbench` 仅作历史验证和回归案例，不是代码依赖。

## 7. 可观察的 v0.1 验收标准（目标，尚待验证）

1. **安装与 Bootstrap：** 空或新 Git 仓库可安装并初始化；无 root commit 的空 clone 可 Bootstrap；Lead Worktree 自动建立并启动所配置 Agent。
2. **恢复与权限：** 重启后 Lead 根据 Git、正式 Baseline、`PROJECT_STATUS.md` 与 Orca 事实恢复，且不依赖聊天记录；用户只与 Lead/Human Gates 交互；G1–G5 均由人批准。
3. **协调负担：** 普通 Worker 的人工 Worktree 创建次数为 0，人工 Prompt 转发次数为 0，Worker 间人工消息转发次数为 0；Lead 能自动 `dispatch → wait → verify → next decision`。Human Gate、方向与高风险决定不计入这些指标。
4. **受控失败路径：** Implementation 与 Independent Review 使用独立 Worktree/Session，即使统一使用 Codex；实际演示 Review Fail → Rework、Baseline 变化 → G4。
5. **完整闭环：** 至少一次可追溯 E2E 从 IDEA 经定义、架构、实现、Review、Acceptance、Integration 到 CLOSED，并保留相应 Gate 与证据。
6. **诊断与发布：** doctor 检查关键安装、状态和 Agent 配置；包、Skill、配置及版本可验证；提供正式开源 README、License、Security、Contribution、版本与 Release 资产；GitHub 上有第三方可 clone、install、reproduce 的 `v0.1.0` Release。

以上为通过条件，不是当前通过记录；场景、执行结果和发布资产须另行留证。

## 8. 假设、风险与范围压力测试

**待验证假设：** 个人及小团队愿意以单一 Lead 作为主要日常入口；Orca 的现有原语足以支撑目标闭环；dogfood 与一个历史回归案例能暴露主要失败路径。这些假设不因方向确认而成为已验证事实。

**风险：** 闭环范围较大，尤其空仓库 Bootstrap、可靠恢复、Review Fail/Rework 和 G4 路径可能使 v0.1 发布延迟；单模型条件可能限制审查的视角独立性，因此必须以 Worktree/Session 隔离和可核查证据约束结论；自动化若误读 Baseline 或授权会越过 Human Gate。风险/变更等级交 `gad-governance` 判定。

**压力测试结论：** v0.1 必须完整验证闭环，不能把功能目录或 Operating Model 的描述当作测试结果。产品价值以协调人工操作减少、恢复正确性、失败路径与人的批准权共同衡量。云控制面、通用框架、跨平台抽象和多 Orchestrator 会扩大边界但不改善首期验收，故排除。G1 只确定价值、范围、环境和可观察结果；架构分解、具体实现机制和交付计划另行治理。
