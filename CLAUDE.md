# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 提供本仓库的开发指南。

## 项目概述

基于 R 语言的 Claude Code 钩子系统，用于自动化代码质量管理，遵循 Unix 哲学（Do one thing well）。

## 常用命令

### 手动运行钩子

```bash
# 会话初始化
Rscript hooks/session_start.R

# 操作前验证
Rscript hooks/pre_tool_use.R

# 操作后格式化和分析
Rscript hooks/post_tool_use.R

# 会话结束汇总
Rscript hooks/stop.R
```

### 安装依赖

```r
install.packages("jsonlite")   # 必需
install.packages("styler")     # 可选，用于 R 代码格式化
```

## 架构说明

### 钩子系统

钩子是在 Claude Code 生命周期事件触发时执行的 R 脚本：
- **输入**: 从 stdin 读取 JSON 数据（钩子上下文）
- **输出**: 写入 stderr 的消息（显示在 Claude Code 界面）
- **日志**: 持久化到 `data/` 目录的 CSV 文件

钩子实现位于 `hooks/` 目录：
- `session_start.R` - 扫描项目，生成 `data/stats.json`
- `pre_tool_use.R` - 文件验证（>10MB 阻止）、敏感信息检测
- `post_tool_use.R` - 通过 `styler::style_file()` 格式化 R 代码、CSV 分析、代码质量评分
- `stop.R` - 会话摘要，包含时长和文件统计
- `prompt_submit.R` - 提示词拦截，用于上下文注入

### 配置

钩子在 `.claude/settings.json` 中配置：
- `SessionStart`: 会话初始化时运行
- `UserPromptSubmit`: 每次提交提示词时运行
- `PreToolUse`: Write/Edit 操作前运行（阻塞式）
- `PostToolUse`: Write/Edit 操作后运行（异步）
- `Stop`: Claude 完成响应后运行（异步）

### 斜杠命令

定义在 `.claude/commands/*.md`：
- `/simplify` - 代码质量分析，遵循 Unix 哲学（函数长度 ≤30 行，嵌套 ≤3 层）
- `/review` - 全面代码审查
- `/format` - 使用 styler 格式化代码

### 数据流

1. Claude Code 事件触发钩子
2. 钩子从 stdin 读取 JSON 上下文
3. 钩子处理（验证/格式化/分析）
4. 钩子写入日志到 `data/hook_log.csv`
5. 钩子更新 `data/stats.json`
6. 钩子输出消息到 stderr

### 代码质量标准

系统在 `post_tool_use.R` 中强制执行以下指标：
- 函数长度：>30 行警告，>50 行严重
- 嵌套深度：>4 层警告（2 空格缩进）
- 行宽限制：100 字符
- 早返回模式，减少嵌套
- 参数数量：>5 个参数警告

### 项目结构

```
├── .claude/
│   ├── settings.json          # 钩子配置
│   └── commands/              # 斜杠命令定义 (*.md)
├── hooks/                     # 钩子实现 (*.R)
├── data/                      # 生成的统计数据（gitignored）
│   ├── stats.json            # 会话统计
│   └── hook_log.csv          # 操作日志
└── messy_code.R              # 用于测试钩子的示例文件
```

### 环境变量

钩子通过以下变量获取上下文：
- `CLAUDE_PROJECT_DIR` - 项目根目录
- `FILEPATH` - 当前操作的文件路径
- `TOOL` - 当前工具名称（Write/Edit/Read）

## 开发注意事项

- UI 消息使用中文输出
- 无正式测试框架 - 使用 `messy_code.R` 进行手动测试
- 钩子日志持久化在 `data/hook_log.csv` 中便于调试
- `pre_tool_use.R` 中检查敏感数据模式（API 密钥、密码、私钥）
