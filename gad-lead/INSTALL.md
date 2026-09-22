# GAD Lead v0.4.0 安装 / 升级

GAD Lead 采用**单目录安装**。将整个 `gad-lead/` 目录放到项目根目录。

```text
<project>/
└── gad-lead/
    ├── README.md
    ├── GAD_LEAD_OPERATING_MODEL.md
    ├── GAD_AGENT_POLICY.conf
    ├── INSTALL.md
    ├── MANIFEST.json
    ├── SHA256SUMS.txt
    ├── gad-lead.cmd
    ├── gad-project.cmd
    └── tools/
        ├── gad-lead.ps1
        └── gad-project.ps1
```

## Agent Preference

默认配置：

```ini
lead = claude
implementation = codex
review = claude
other = default
```

`default` / 空值 / 缺失 / `system` / `auto` / 无效或不可用 Agent 均回到 Orca configured Default Agent。

## 已有项目

替换整个 `gad-lead/` 后，先只做只读验证：

```powershell
.\gad-lead\gad-lead.cmd version
.\gad-lead\gad-lead.cmd doctor
.\gad-lead\gad-lead.cmd agent --role lead
.\gad-lead\gad-lead.cmd agent --role implementation
.\gad-lead\gad-lead.cmd agent --role review
.\gad-lead\gad-lead.cmd agent --role other
```

如果 `gad-lead/` 已被 Git 跟踪，替换会产生工作树变更。不要把它静默当成已批准 Baseline；按项目治理规则由 GAD Lead 审查并提交这次工具升级。

## 新项目

使用 `gad-project` 安装 GAD Skills + GAD Lead：

```powershell
.\gad-lead\gad-project.cmd new `
  --name "new-project" `
  --parent "C:\Users\app\orca\projects" `
  --gad-core "C:\Users\app\gad-core" `
  --commit `
  --start-lead
```

`--start-lead` 需要已有 Git HEAD，因此新项目需配合 `--commit`。

## 元数据

`MANIFEST.json` 与 `SHA256SUMS.txt` 不参与正常运行，但用于版本识别和完整性校验。
