# R Language Claude Code Hooks

使用 R 语言编写的 Claude Code 钩子，实现项目自动化管理。

## Hooks 说明

### 1. SessionStart Hook

**触发时机**: Claude Code 会话开始时

**功能**:
- 扫描项目目录，统计文件数量
- 识别 R、JSON、CSV 等文件类型
- 生成 `data/stats.json` 初始统计

**输出示例**:
```
╔══════════════════════════════════════════════════════════════╗
║           R Hooks Session Start                              ║
╚══════════════════════════════════════════════════════════════╝

📁 项目目录: D:/GitHub/kongdd/hooks
📊 文件总数: 3
📄 R 文件数: 1
   └─ example_analysis.R
📄 JSON 文件数: 0
📄 CSV 文件数: 1

✅ 统计信息已保存: data/stats.json
```

---

### 2. PreToolUse Hook

**触发时机**: 执行 Write/Edit 工具前

**功能**:
- 检查文件大小（>10MB 阻止）
- 检测敏感信息（API Key、密码、私钥等）
- 记录操作日志到 `data/hook_log.csv`

**检测模式**:
| 类型 | 正则模式 |
|------|----------|
| API Key | `api[_-]?key` |
| 密码 | `password\|passwd\|pwd` |
| 密钥/Token | `secret[_-]?key\|token` |
| 私钥 | `BEGIN (RSA\|OPENSSH\|DSA\|EC) PRIVATE KEY` |

**退出码**:
- `0`: 允许操作
- `2`: 阻止操作（文件过大）

---

### 3. PostToolUse Hook

**触发时机**: 执行 Write/Edit 工具后（异步）

**功能**:
- R 文件自动格式化（使用 `styler` 包）
- CSV 文件预览（列数、行数）
- 更新 `stats.json` 统计
- 记录操作日志

**R 文件格式化**:
- 自动调用 `styler::style_file()`
- 需要安装 `styler` 包: `install.packages("styler")`

**CSV 分析**:
- 读取前 100 行预览
- 输出列数和估计行数

---

### 4. Stop Hook

**触发时机**: Claude 完成响应后（异步）

**功能**:
- 计算会话时长
- 统计文件修改次数
- 汇总各 hook 触发次数
- 生成会话摘要报告

**输出示例**:
```
╔══════════════════════════════════════════════════════════════╗
║           R Hooks Session Summary                            ║
╚══════════════════════════════════════════════════════════════╝

⏱️  会话时长: 1.5 分钟
📝 文件修改: 5
📄 R 文件数: 2

🔔 Hooks 触发统计:
   • SessionStart: 1
   • PreToolUse: 3
   • PostToolUse: 2
   • Stop: 1

📊 文件操作详情:
   • 总计: 10
   • 格式化: 2
   • 允许: 5
   • 警告: 1
   • 错误: 0
```

---

## 数据文件

### stats.json

存储项目统计和会话信息:

```json
{
  "session_start": "2026-02-24T00:00:00Z",
  "project_dir": "D:/project",
  "total_files": 10,
  "r_files": ["main.R", "utils.R"],
  "files_modified": 3,
  "hooks_triggered": {
    "SessionStart": 1,
    "PreToolUse": 2,
    "PostToolUse": 2,
    "Stop": 0
  }
}
```

### hook_log.csv

记录所有 hook 操作日志:

```csv
timestamp,hook_type,tool,filepath,status,message
2026-02-24 00:00:00,PreToolUse,Write,main.R,allowed,检查通过
2026-02-24 00:00:01,PostToolUse,Write,main.R,formatted,格式化完成
```

---

## 安装配置

### 1. 安装 R 依赖

```r
install.packages("jsonlite")
install.packages("styler")  # 可选，用于 R 代码格式化
```

### 2. 配置 Claude Code

确保 `.claude/settings.json` 包含:

```json
{
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "Rscript hooks/session_start.R"}]}],
    "PreToolUse": [{"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "Rscript hooks/pre_tool_use.R"}]}],
    "PostToolUse": [{"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "Rscript hooks/post_tool_use.R", "async": true}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "Rscript hooks/stop.R", "async": true}]}]
  }
}
```

### 3. 重启 Claude Code

配置修改后需要重启会话生效。

---

## 环境变量

Hooks 通过环境变量获取上下文:

| 变量名 | 说明 |
|--------|------|
| `CLAUDE_PROJECT_DIR` | 项目根目录 |
| `FILEPATH` | 当前操作的文件路径 |
| `TOOL` | 当前工具名称（Write/Edit/Read） |

---

## 项目结构

```
.
├── .claude/
│   ├── settings.json          # hooks 配置
│   └── settings.local.json    # 本地配置（gitignored）
├── hooks/
│   ├── session_start.R        # 会话开始 hook
│   ├── pre_tool_use.R         # 工具使用前 hook
│   ├── post_tool_use.R        # 工具使用后 hook
│   └── stop.R                 # 会话结束 hook
├── data/
│   ├── stats.json             # 统计信息（自动生成）
│   └── hook_log.csv           # 操作日志（自动生成）
└── README.md
```

---

## 系统要求

- R >= 4.0
- R 包: `jsonlite`
- 可选: `styler`（R 代码格式化）

---

## 许可证

MIT License
