# Claude Code Hooks 完整指南

本文档综合了 Claude Code CLI hooks 和 Agent SDK hooks 的编写方法。

---

## 目录

1. [Claude Code CLI Hooks](#claude-code-cli-hooks)
   - [配置文件结构](#配置文件结构)
   - [Hook 类型](#hook-类型)
   - [编写规范](#编写规范)
   - [输入/输出约定](#输入输出约定)
   - [实战示例](#实战示例)
2. [Agent SDK Hooks](#agent-sdk-hooks)
   - [可用 Hook 类型](#可用-hook-类型-sdk)
   - [配置方式](#配置方式-sdk)
   - [输入数据字段](#输入数据字段)
   - [返回数据结构](#返回数据结构)
   - [高级用法](#高级用法)
3. [两者对比](#两者对比)

---

## Claude Code CLI Hooks

Claude Code CLI 通过 shell 脚本实现 hooks，在 `.claude/settings.json` 中配置。

### 配置文件结构

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{ "type": "command", "command": "Rscript hooks/session_start.R" }]
    }],
    "UserPromptSubmit": [{
      "hooks": [{ "type": "command", "command": "Rscript hooks/prompt_submit.R" }]
    }],
    "PreToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{ "type": "command", "command": "Rscript hooks/pre_tool_use.R" }]
    }],
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{ "type": "command", "command": "Rscript hooks/post_tool_use.R", "async": true }]
    }],
    "Stop": [{
      "hooks": [{ "type": "command", "command": "Rscript hooks/stop.R", "async": true }]
    }]
  }
}
```

### Hook 类型

| Hook 类型 | 触发时机 | 用途 | 可阻止 |
|-----------|----------|------|--------|
| `SessionStart` | 会话开始时 | 初始化、项目扫描、统计 | 否 |
| `UserPromptSubmit` | 用户提交 prompt 时 | 注入上下文、验证输入 | 否 |
| `PreToolUse` | 工具执行**前** | 验证、安全检查、阻止操作 | **是** |
| `PostToolUse` | 工具执行**后** | 格式化、分析、日志记录 | 否 |
| `Stop` | 会话结束时 | 生成报告、清理资源 | 否 |

### 编写规范

```r
#!/usr/bin/env Rscript
# Hook 名称 - 简短描述

suppressPackageStartupMessages(library(jsonlite))

# 空值合并操作符
`%||%` <- function(x, y) if (is.null(x)) y else x

# 从 stdin 读取 JSON 输入
read_stdin <- function() {
  if (interactive()) return(NULL)
  lines <- readLines(file("stdin"), warn = FALSE)
  if (length(lines) == 0) return(NULL)
  tryCatch(fromJSON(paste(lines, collapse = "\n")), error = function(e) NULL)
}

# 日志记录函数
log_hook <- function(dir, tool, file, status, msg) {
  entry <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    hook_type = "HookType",
    tool = tool,
    filepath = basename(file),
    status = status,
    message = msg,
    stringsAsFactors = FALSE
  )
  log_file <- file.path(dir, "data", "hook_log.csv")
  write.table(entry, log_file, append = file.exists(log_file),
              sep = ",", row.names = FALSE, col.names = !file.exists(log_file))
}

main <- function() {
  # 1. 读取输入
  input <- read_stdin()

  # 2. 提取信息
  tool <- input$tool %||% Sys.getenv("TOOL", "Unknown")
  file <- input$tool_input$filepath %||% input$filepath %||% Sys.getenv("FILEPATH", "")
  dir <- Sys.getenv("CLAUDE_PROJECT_DIR", getwd())

  # 3. 执行逻辑...

  # 4. 日志输出到 stderr
  cat("处理中...\n", file = stderr())

  # 5. 返回结果到 stdout（可选）
  # result <- list(continue = TRUE, hookSpecificOutput = list(...))
  # cat(toJSON(result, auto_unbox = TRUE), "\n")

  # 6. 返回码: 0=成功/允许, 2=阻止(仅PreToolUse)
  invisible(0)
}

main()
```

### 输入/输出约定

| 通道 | 用途 | 示例 |
|------|------|------|
| **stdin** | 接收 hook 数据 | JSON 格式的工具信息 |
| **stderr** | 日志输出 | `cat("处理中\n", file = stderr())` |
| **stdout** | 返回数据 | `cat(toJSON(result), "\n")` |
| **返回码** | 控制行为 | `0`=允许, `2`=阻止 |

### 环境变量

| 变量 | 说明 |
|------|------|
| `CLAUDE_PROJECT_DIR` | 项目根目录 |
| `FILEPATH` | 当前操作的文件路径 |
| `TOOL` | 当前工具名称 |

### stdin JSON 结构

```json
{
  "tool": "Write",
  "tool_input": {
    "filepath": "/path/to/file.R",
    "content": "..."
  },
  "prompt": "用户输入的 prompt (UserPromptSubmit)"
}
```

### 返回数据结构

```r
# UserPromptSubmit - 注入上下文
result <- list(
  continue = TRUE,
  hookSpecificOutput = list(
    hookEventName = "UserPromptSubmit",
    additionalContext = "遵循 Unix 哲学：Do one thing well"
  )
)
cat(toJSON(result, auto_unbox = TRUE), "\n")

# PreToolUse - 阻止操作（或返回码 2）
result <- list(
  hookSpecificOutput = list(
    hookEventName = "PreToolUse",
    permissionDecision = "deny",
    permissionDecisionReason = "不允许修改 .env 文件"
  )
)
```

### 实战示例

#### 1. SessionStart - 项目扫描

```r
#!/usr/bin/env Rscript
# SessionStart Hook - 扫描项目，生成统计信息

suppressPackageStartupMessages(library(jsonlite))

scan_project <- function(dir) {
  old <- setwd(dir)
  on.exit(setwd(old))

  files <- list.files(".", recursive = TRUE, full.names = FALSE)
  files <- files[!grepl("^[.]|(data|hooks)[/\\]", files)]

  stats <- list(total = 0, types = list(), r = c())
  for (f in files) {
    ext <- tolower(tools::file_ext(f))
    stats$total <- stats$total + 1
    stats$types[[ext]] <- (stats$types[[ext]] %||% 0) + 1
    if (ext %in% c("r", "rmd")) stats$r <- c(stats$r, f)
  }
  stats
}

main <- function() {
  project_dir <- Sys.getenv("CLAUDE_PROJECT_DIR", getwd())
  stats <- scan_project(project_dir)

  cat("\n📁 项目目录: ", project_dir, "\n", file = stderr())
  cat("📊 文件总数: ", stats$total, "\n", file = stderr())

  # 保存统计信息
  session_data <- list(
    session_start = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
    project_dir = project_dir,
    total_files = stats$total,
    r_files = stats$r
  )
  write_json(session_data, "data/stats.json", pretty = TRUE, auto_unbox = TRUE)

  invisible(0)
}

main()
```

#### 2. PreToolUse - 安全检查

```r
#!/usr/bin/env Rscript
# PreToolUse Hook - 验证文件操作

suppressPackageStartupMessages(library(jsonlite))

`%||%` <- function(x, y) if (is.null(x)) y else x

read_stdin <- function() {
  if (interactive()) return(NULL)
  lines <- readLines(file("stdin"), warn = FALSE)
  tryCatch(fromJSON(paste(lines, collapse = "\n")), error = function(e) NULL)
}

check_sensitive <- function(f) {
  if (!file.exists(f)) return(list(ok = TRUE, msg = "新文件"))

  content <- paste(readLines(f, warn = FALSE, n = 100), collapse = "\n")

  patterns <- c(
    "api[_-]?key" = "API Key",
    "password|passwd|pwd" = "密码",
    "secret[_-]?key|token" = "密钥/Token",
    "BEGIN (RSA|OPENSSH) PRIVATE KEY" = "私钥"
  )

  for (p in names(patterns)) {
    if (grepl(p, content, ignore.case = TRUE)) {
      return(list(ok = FALSE, msg = sprintf("检测到%s", patterns[p])))
    }
  }
  list(ok = TRUE, msg = "检查通过")
}

main <- function() {
  input <- read_stdin()
  tool <- input$tool %||% Sys.getenv("TOOL", "Unknown")
  file <- input$tool_input$filepath %||% input$filepath %||% ""

  cat(sprintf("\n🔍 PreToolUse: %s | 文件: %s\n", tool, file), file = stderr())

  # 文件大小检查
  if (file.exists(file) && file.info(file)$size > 10 * 1024 * 1024) {
    cat("   ❌ 文件超过 10MB\n", file = stderr())
    return(invisible(2))  # 阻止操作
  }

  # 敏感信息检查
  result <- check_sensitive(file)
  cat(sprintf("   %s %s\n", if (result$ok) "✅" else "⚠️", result$msg), file = stderr())

  invisible(0)
}

main()
```

#### 3. PostToolUse - 代码格式化

```r
#!/usr/bin/env Rscript
# PostToolUse Hook - 格式化代码

suppressPackageStartupMessages(library(jsonlite))

`%||%` <- function(x, y) if (is.null(x)) y else x

read_stdin <- function() {
  if (interactive()) return(NULL)
  lines <- readLines(file("stdin"), warn = FALSE)
  tryCatch(fromJSON(paste(lines, collapse = "\n")), error = function(e) NULL)
}

format_r <- function(f) {
  if (!requireNamespace("styler", quietly = TRUE)) {
    return(list(ok = FALSE, msg = "styler 未安装"))
  }
  tryCatch({
    styler::style_file(f)
    list(ok = TRUE, msg = "格式化完成")
  }, error = function(e) list(ok = FALSE, msg = e$message))
}

main <- function() {
  input <- read_stdin()
  tool <- input$tool %||% Sys.getenv("TOOL", "Unknown")
  file <- input$tool_input$filepath %||% input$filepath %||% ""

  if (file == "") return(invisible(0))

  ext <- tolower(tools::file_ext(file))
  cat(sprintf("\n📝 PostToolUse: %s | 文件: %s\n", tool, file), file = stderr())

  # R 文件格式化
  if (ext %in% c("r", "rmd")) {
    r <- format_r(file)
    cat(sprintf("   %s %s\n", if (r$ok) "✅" else "ℹ️", r$msg), file = stderr())
  }

  invisible(0)
}

main()
```

#### 4. UserPromptSubmit - 注入上下文

```r
#!/usr/bin/env Rscript
# UserPromptSubmit Hook - 注入额外上下文

suppressMessages(library(jsonlite))

return_json <- function(data) {
  cat(toJSON(data, auto_unbox = TRUE), "\n")
}

main <- function() {
  hook_data <- fromJSON(readLines(file("stdin")))
  user_prompt <- hook_data$prompt

  # 分析 prompt 并注入上下文
  additional_context <- ""

  if (grepl("(写|编写|代码|function|优化|重构)", user_prompt)) {
    additional_context <- "[规范] 遵循 Unix 哲学：Do one thing well"
    cat("[Hook] 注入代码规范提示\n", file = stderr())
  }

  if (grepl("(解释|说明|什么是)", user_prompt)) {
    additional_context <- "[规范] 给出逐步解释和示例"
    cat("[Hook] 注入解释类提示\n", file = stderr())
  }

  # 返回结果
  result <- list(
    continue = TRUE,
    hookSpecificOutput = list(
      hookEventName = "UserPromptSubmit",
      additionalContext = additional_context
    )
  )

  return_json(result)
}

main()
```

---

## Agent SDK Hooks

Agent SDK 通过代码配置 hooks，支持 Python 和 TypeScript。

### 可用 Hook 类型 (SDK)

| Hook 事件 | Python | TypeScript | 触发时机 | 典型用途 |
|-----------|--------|------------|----------|----------|
| `PreToolUse` | ✅ | ✅ | 工具调用前（可阻止） | 阻止危险命令 |
| `PostToolUse` | ✅ | ✅ | 工具执行后 | 记录审计日志 |
| `PostToolUseFailure` | ❌ | ✅ | 工具执行失败 | 错误处理 |
| `UserPromptSubmit` | ✅ | ✅ | 用户提交 prompt | 注入上下文 |
| `Stop` | ✅ | ✅ | Agent 停止 | 保存会话状态 |
| `SubagentStart` | ❌ | ✅ | 子 Agent 启动 | 追踪任务 |
| `SubagentStop` | ✅ | ✅ | 子 Agent 完成 | 汇总结果 |
| `PreCompact` | ✅ | ✅ | 对话压缩前 | 归档记录 |
| `PermissionRequest` | ❌ | ✅ | 权限请求时 | 自定义权限 |
| `SessionStart` | ❌ | ✅ | 会话开始 | 初始化 |
| `SessionEnd` | ❌ | ✅ | 会话结束 | 清理资源 |
| `Notification` | ❌ | ✅ | 状态通知 | 推送通知 |

### 配置方式 (SDK)

#### Python

```python
import asyncio
from claude_agent_sdk import query, ClaudeAgentOptions, HookMatcher

async def my_hook(input_data, tool_use_id, context):
    # Hook 逻辑
    return {}

async def main():
    async for message in query(
        prompt="Your prompt",
        options=ClaudeAgentOptions(
            hooks={
                "PreToolUse": [
                    HookMatcher(matcher="Write|Edit", hooks=[my_hook])
                ]
            }
        ),
    ):
        print(message)

asyncio.run(main())
```

#### TypeScript

```typescript
import { query, HookCallback, PreToolUseHookInput } from "@anthropic-ai/claude-agent-sdk";

const myHook: HookCallback = async (input, toolUseID, { signal }) => {
  // Hook 逻辑
  return {};
};

for await (const message of query({
  prompt: "Your prompt",
  options: {
    hooks: {
      PreToolUse: [{ matcher: "Write|Edit", hooks: [myHook] }]
    }
  }
})) {
  console.log(message);
}
```

### 输入数据字段

**通用字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `hook_event_name` | string | Hook 类型 |
| `session_id` | string | 会话 ID |
| `transcript_path` | string | 对话记录路径 |
| `cwd` | string | 当前工作目录 |

**工具相关字段** (PreToolUse/PostToolUse)：
| 字段 | 类型 | 说明 |
|------|------|------|
| `tool_name` | string | 工具名称 |
| `tool_input` | object | 工具参数 |
| `tool_response` | any | 工具返回结果 (PostToolUse) |

**UserPromptSubmit 字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `prompt` | string | 用户输入的 prompt |

### 返回数据结构

```typescript
// 允许操作
return {};

// 阻止操作 (PreToolUse)
return {
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",  // allow | deny | ask
    permissionDecisionReason: "原因说明"
  }
};

// 修改工具输入
return {
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    updatedInput: { file_path: "/sandbox/file" }
  }
};

// 注入系统消息
return {
  systemMessage: "Remember to follow security best practices."
};

// 注入上下文 (UserPromptSubmit)
return {
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: "额外的上下文信息"
  }
};
```

### 权限决策流程

```
1. Deny 规则优先检查（任何匹配 = 立即拒绝）
2. Ask 规则检查
3. Allow 规则检查
4. 默认 Ask
```

### Matcher 配置

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `matcher` | string | undefined | 正则匹配工具名 |
| `hooks` | array | - | 回调函数数组 |
| `timeout` | number | 60 | 超时秒数 |

```python
# 匹配文件修改工具
HookMatcher(matcher="Write|Edit|Delete", hooks=[callback])

# 匹配所有 MCP 工具
HookMatcher(matcher="^mcp__", hooks=[callback])

# 匹配所有工具
HookMatcher(hooks=[callback])
```

### 高级用法

#### 链式 Hooks

```python
options = ClaudeAgentOptions(
    hooks={
        "PreToolUse": [
            HookMatcher(hooks=[rate_limiter]),      # 1. 限流
            HookMatcher(hooks=[authorization]),     # 2. 授权
            HookMatcher(hooks=[sanitizer]),         # 3. 清理
            HookMatcher(hooks=[audit_logger]),      # 4. 日志
        ]
    }
)
```

#### 异步操作

```python
import aiohttp

async def webhook_notifier(input_data, tool_use_id, context):
    if input_data["hook_event_name"] != "PostToolUse":
        return {}

    try:
        async with aiohttp.ClientSession() as session:
            await session.post(
                "https://api.example.com/webhook",
                json={"tool": input_data["tool_name"]}
            )
    except Exception as e:
        print(f"Webhook failed: {e}")

    return {}
```

---

## 两者对比

| 方面 | CLI Hooks | SDK Hooks |
|------|-----------|-----------|
| **配置位置** | `.claude/settings.json` | 代码中 |
| **实现语言** | 任意 (R, Python, Bash) | Python / TypeScript |
| **输入方式** | stdin JSON | 函数参数 |
| **输出方式** | stdout JSON / 返回码 | return 对象 |
| **日志方式** | stderr | console.log |
| **阻止操作** | 返回码 2 | `permissionDecision: "deny"` |
| **异步支持** | `async: true` 配置 | 原生 async/await |
| **可用 Hook 数量** | 5 种 | 12 种 |

### 选择建议

| 场景 | 推荐 |
|------|------|
| Claude Code CLI 扩展 | CLI Hooks |
| 自定义 Agent 应用 | SDK Hooks |
| 简单验证/日志 | CLI Hooks |
| 复杂业务逻辑 | SDK Hooks |
| 需要调用外部 API | SDK Hooks (更好的异步支持) |

---

## 最佳实践

1. **单一职责** - 每个 hook 只做一件事
2. **幂等性** - 多次执行结果一致
3. **快速执行** - 避免耗时操作（或使用 async）
4. **健壮性** - 处理空值和异常情况
5. **日志记录** - 输出到 stderr 便于调试
6. **安全优先** - Deny 规则放在最前面

---

## 参考资源

- [Agent SDK Hooks 官方文档](https://platform.claude.com/docs/en/agent-sdk/hooks.md)
- [Python SDK Reference](https://platform.claude.com/docs/en/agent-sdk/python)
- [TypeScript SDK Reference](https://platform.claude.com/docs/en/agent-sdk/typescript)
