#!/usr/bin/env Rscript
# PreToolUse Hook - 从stdin读取数据，验证文件操作

suppressPackageStartupMessages(library(jsonlite))
source(file.path(Sys.getenv("CLAUDE_PROJECT_DIR", getwd()), "R", "hooks.R"))

check_sensitive <- function(f) {
  if (!file.exists(f)) return(list(ok = TRUE, msg = "新文件"))

  content <- paste(readLines(f, warn = FALSE, n = 100), collapse = "\n")
  if (!nchar(content)) return(list(ok = TRUE, msg = "空文件"))

  patterns <- c(
    "api[_-]?key" = "API Key",
    "password|passwd|pwd" = "密码",
    "secret[_-]?key|token" = "密钥/Token",
    "BEGIN (RSA|OPENSSH|DSA|EC) PRIVATE KEY" = "私钥"
  )

  for (p in names(patterns)) {
    if (grepl(p, content, ignore.case = TRUE)) {
      return(list(ok = FALSE, msg = sprintf("检测到%s", patterns[p])))
    }
  }

  list(ok = TRUE, msg = "检查通过")
}

main <- function() {
  ctx <- get_hook_context()
  dir <- get_project_dir()

  if (ctx$file == "") {
    log_stderr("\n⚠️  PreToolUse: 未指定文件路径\n")
    log_hook(dir, "PreToolUse", ctx$tool, "", "warning", "未指定文件路径")
    return(invisible(0))
  }

  log_stderr("\n🔍 PreToolUse: %s\n   文件: %s\n", ctx$tool, ctx$file)

  if (file.exists(ctx$file) && file.info(ctx$file)$size > 10 * 1024 * 1024) {
    log_stderr("   ❌ 文件超过 10MB\n")
    log_hook(dir, "PreToolUse", ctx$tool, ctx$file, "blocked", "文件过大")
    return(invisible(2))
  }

  result <- check_sensitive(ctx$file)
  log_stderr("   %s %s\n", if (result$ok) "✅" else "⚠️", result$msg)
  log_hook(dir, "PreToolUse", ctx$tool, ctx$file, if (result$ok) "allowed" else "warning", result$msg)

  update_stats(dir, "PreToolUse")

  log_stderr("\n")
  invisible(0)
}

main()
