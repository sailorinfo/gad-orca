# ARCHITECTURE — gad-orca

## 1. 架构目标与原则

gad-orca 是运行于 Orca 之上的 GAD 治理与自动化交付层。v0.1 的架构应支撑 `PROJECT.md` 所定义的 IDEA 到 CLOSED 完整闭环、状态恢复、证据核验、受控失败路径、Human Gates、空 clone Bootstrap 与第三方复现。`PROJECT.md` 第 7 节的六组可观察验收标准全部保留，仍须以实际执行和发布证据验证；本架构文本不构成通过记录。

架构原则是：人保留方向、高风险决定和 G1–G5 批准权；GAD Skills 定义生命周期语义，GAD Lead 协调合法动作，Orca 提供唯一正式 Orchestrator 的执行原语；持久事实、实时执行事实与批准授权分开；优先复用现有能力，只在真实需求支持时扩展。v0.1 目标环境为 Windows 10/11、PowerShell、Git、Orca、GAD Skills 与 Codex。跨平台适配、非 Orca 运行、第二 Orchestrator、通用 Agent Framework、云控制面、多租户和长期后台服务均不属于本期架构。

## 2. 系统与外部边界

```text
人（方向、G1–G5、高风险决定）
  ↕ 决策包与明确批准
GAD Lead（唯一日常通信入口；恢复、协调、核验证据）
  ↔ GAD Skills（生命周期、角色、Gate 与所有权语义）
  ↔ Git + 正式 Baseline + PROJECT_STATUS.md（持久项目事实）
  ↔ Orca（唯一 Orchestrator：Worktree、Terminal、Agent 启动、会话）
      ↔ 隔离的专职 Worker
```

Git 与正式受控文档承载持久项目事实，Orca 提供实时执行拓扑。聊天记忆、Worker 自述及 Lead 工作笔记不是批准或项目状态的最终来源。GitHub 是克隆和 Release 分发边界，不参与日常 Gate 决策。`crypto-trading-workbench` 可作历史回归案例，不成为产品代码依赖。

gad-orca 不重写 Orca 的 Worktree、Terminal、Agent 启动与基础编排，不建立平行队列、调度器或 Orca 状态数据库。GAD Lead 对 Orca 的调用是治理决策的执行边界，而非第二套 Orchestrator。

## 3. 模块与责任

| 边界 | 目的与拥有的责任 | 消费 → 产出 | 不得承担 |
|---|---|---|---|
| GAD 方法论与 Skills | 生命周期、角色、Gate 和工件所有权语义 | 批准基线与事实 → 合法动作及交接约束 | 代人批准、越权修改工件或接管 Orca |
| GAD Lead 协调 | 唯一用户/Worker 通信入口；恢复、Reflection、Worktree Decision、监督与证据核验 | 主线基线/状态、Git/Orca/Worker 证据 → Worker 合同、下一合法动作、Gate 决策包 | 修改正式工件或产品代码、充当实现者/独立审查者、自批 Gate |
| 项目事实与证据 | 保留可定位的版本、状态、批准、提交和审查结论 | 正式工件、Git 与获核验证据 → 可恢复、可审计的项目事实 | 以瞬时 Orca/聊天状态静默覆盖正式状态 |
| 安装、Bootstrap 与诊断 | 在目标仓库安装 Skills/Lead，建立可启动的 Git 基础并诊断依赖 | 发布包、目标仓库、Orca/Agent 配置 → 安装结果、Lead 入口、诊断 | 假定空 clone 已有 HEAD、静默覆盖用户文件、伪造批准 |
| Orca 接入 | 将合法 Worktree Decision 映射到 Orca 原生能力，并读取实时结果 | 精确 Git base、Orca parent、Agent 解析 → Worktree/Terminal/Agent 句柄与拓扑 | 自建 Orchestrator、隐藏 Orca 冲突、绕过隔离 |
| 专职 Worker | 在有界所有权和授权下执行 Inception、Architecture、Governance、Research、Readiness、Implementation、Review、Rework、Integration 等角色任务 | 精确基线与合同 → 限定工件、提交、验证或阻塞报告 | 直接向用户索取 Gate、跨角色改正式工件、自行批准或越权集成 |

Skills 提供语义约束，Lead 消费语义并作协调决定，安装与 Orca 接入提供基础设施能力，Worker 执行限定工作并返还证据；正式状态由获授权的工件所有者更新。读取证据的能力不授予写入或批准权。仅当多个真实模块反复需要同一能力时才提取共享层；配置、诊断、版本识别先复用现有包内边界。

## 4. 控制、数据与证据流

1. **启动与恢复：** 每次启动/恢复先定位主线，读取正式 Baseline 和主线 `PROJECT_STATUS.md`，再核对 Git refs/status、Orca Worktree/Terminal/lineage、Worker 提交、独立审查及 A2 材料。冲突须显式记录，依赖冲突事实的动作暂停。Lead 可从这些材料重做 `RECONCILE → REFLECT → DECIDE`，不得从聊天摘要推断批准。
2. **Human Gate：** 治理判断需要 G1–G5 时，Lead 形成有精确对象、证据、反证/未知、建议、获批后动作和回退路径的决策包。只有人对适用 Gate 与目标的明确批准能授权后续受控动作；提案、Worker 报告及澄清不能替代批准。获授权的工件所有者负责正式晋升，Lead 负责核验。
3. **Worker 执行：** Lead 在合法模式与授权范围内先形成 Worktree Decision，再通过 Orca 创建、复用或恢复 Worker，并传递有界合同；随后监控、核对提交/差异/验证、路由审查并决定下一步。普通 Worker 的 Worktree 创建、Prompt 与消息传递由 Lead/Orca 协调，不要求人充当转发者。
4. **Review、Rework 与变更：** Implementation 与 Independent Review 使用独立 Worktree/Session，即使均使用 Codex。Review Fail 且基线不变时，由原实现所有者 Rework，随后重新独立审查；若需变更正式 Baseline，停止旧执行路径并交 G4，由人批准后受控晋升、重新评估。Acceptance、Integration 和 CLOSED 均需相应证据，不能仅凭 Lead 自述完成。
5. **证据链：** 决策应可追到主线版本、适用 Gate 批准、Worker base/final commit、变更文件、验证、Review 结论和 Orca lineage/句柄。Orca 实时事实可能失效，持久结论须能由 Git、正式工件与留存记录复核，而无需另建平行 Orca 数据库。

## 5. 关键合同与不变量

- **Worker 合同：** 指明角色、权威工件、精确 Git base、允许/禁止文件与命令、预期产出、验证、升级路径、no-merge/no-push 约束及完成/阻塞返回。`WORKER_DONE` 表示待核验交付，非接受；`WORKER_BLOCKED` 应给最小阻塞事实、证据、基线影响及需否人决策。
- **Git base 与 Orca parent：** Git base 固定代码/基线快照，Orca parent 固定协调 lineage；两者不能互相推断。独立审查必须指向精确待审提交并拥有独立 Worktree/Session；同模型不免除隔离。
- **Agent Preference：** Lead 仅表达角色偏好，Orca 拥有 Agent 安装、可用性、默认值和启动配置。无法解析到具体可用 Agent 时给出可诊断阻塞，不暗设硬编码替代者。
- **运行模式：** Shadow 只读；Bootstrap 服务项目定义、架构、治理基线和 Lead 正式采纳；Active 需正式批准。模式转换不自动批准 G1–G5，也不授权产品 Batch。
- **事实与授权：** 主线正式 Baseline/状态、Git、Orca、Worker/Review、A2 材料分别按其证据性质核对；冲突不被静默覆盖。读取事实不授予执行权，工具成功返回不等于目标场景验证通过。

## 6. 安装、无 HEAD 空 clone 与恢复

安装/初始化须覆盖新仓库、已有 Git 仓库及无 root commit 的空 clone。Orca Worktree 建立需要可用 Git HEAD；无 HEAD 路径须先在安装/Bootstrap 边界建立可审计、可重复、不误纳入用户文件的合法 root commit，再启动 Lead Worktree。该机械初始化不代表任何 Human Gate 批准，也不得制造伪正式 Baseline。已有 HEAD 不得被自动重写历史；部分安装、重复运行和冲突应有明确诊断与恢复位置。

现有 `gad-project` 的安装/初始化入口、`gad-lead` 的 start/resume/transition/status/doctor/agent 入口、Agent Preference、manifest 和 hash 列表可作为演进起点。它们的存在不证明空 clone、恢复、第三方安装或 Release 已通过验证。后续交付须实际验证主线发现、Orca 句柄恢复、冲突及重复启动行为，并对照 `PROJECT.md` 的成功标准留证。

## 7. 架构风险与范围控制

| 风险 | 约束与待验证证据 |
|---|---|
| Lead 协调与事实解释集中，可能越权 | Lead 消费正式状态与实时事实，不自改 Baseline/状态或自批 Gate；以重启恢复和事实冲突场景验证。 |
| 空 clone 无 HEAD 与 Orca Worktree 前置条件冲突 | 先建立可审计 root commit；以真实无 HEAD 空 clone 验证自动 Bootstrap 与重复运行安全性。 |
| 同模型审查可能缺少视角独立性 | 保持独立 Worktree/Session、精确审查对象和可核查证据；演示 Review Fail → Rework → 重审。 |
| 文档与运行能力混淆 | 对 `PROJECT.md` 六组成功标准分别保留执行、Gate 和发布证据；不得把功能清单当测试结论。 |
| Worker 上下文过载或共享状态隐蔽 | 给每个角色清晰所有权、精确 base 与禁止触碰边界；Lead 笔记不承载正式状态。 |
| Orca 运行原语或配置变化 | 接入边界保留 Orca 原始结果与不可用诊断，由 doctor 暴露问题；不预建未来编排器适配框架。 |

第二 Orchestrator、跨平台适配层、通用 Agent Framework、长期后台服务、模型评分和复杂路由不改善已批准的 v0.1 成功标准，故不进入本期架构。完整闭环、失败路径与 Human Authority 不能因实现难度被架构文档缩减。风险等级、治理 Profile 和 Gate 路由由 `gad-governance` 判定。

## 8. 开发依赖与延后决定

能力依赖顺序为：确立 G2 架构与治理基线；由 Readiness 将成功标准转成有界交付和验证；打通安装/空 clone Bootstrap、恢复及状态/证据合同；完成 Worker、独立 Review、Rework、G4 与 Acceptance/Integration 路径；最后以 gad-orca dogfood E2E、历史回归、doctor 和第三方 v0.1.0 Release 复现核验整体目标。这是高层依赖关系，不是 Batch 授权、Worker DAG 或文件级实施计划。

普通能力的 Program/Tool/MCP/Skill/Agent/Orchestration 分配、脚本内结构、详细 schema、错误码、持久记录格式、安装重试算法、Worker 数量、库/SDK 和具体测试实现均延后至 `gad-implementation-readiness`。若 Orca 原语、恢复语义或兼容性的新证据实质改变架构边界，应先提出决策型研究或受控架构变更，不以实现中的便利选择暗改本基线。
