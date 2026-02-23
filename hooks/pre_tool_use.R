#!/usr/bin/env Rscript
# PreToolUse Hook - 工具使用前执行
# 用途：验证文件操作，检查敏感信息

suppressPackageStartupMessages(library(jsonlite))

# 从环境变量获取参数
get_env <- function(name, default = NULL) {
  val <- Sys.getenv(name, unset = "")
  if (val == "") default else val
}

# 检查敏感信息
check_sensitive_info <- function(filepath) {
  if (!file.exists(filepath)) {
    return(list(safe = TRUE, reason = "文件不存在（新文件）"))
  }

  content <- tryCatch(
    readLines(filepath, warn = FALSE),
    error = function(e) return(character())
  )

  content_str <- paste(content, collapse = "\n")

  # 敏感模式检查
  patterns <- list(
    api_key = list(
      pattern = "(?i)(api[_-]?key|apikey)\\s*[:=]\\s*['\"]?[a-z0-9]{16,}['\"]?",
      desc = "API Key"
    ),
    password = list(
      pattern = "(?i)(password|passwd|pwd)\\s*[:=]\\s*['\"][^'\"]{4,}['\"]",
      desc = "密码"
    ),
    secret = list(
      pattern = "(?i)(secret|token)\\s*[:=]\\s*['\"]?[a-z0-9]{16,}['\"]?",
      desc = "密钥/Token"
    ),
    private_key = list(
      pattern = "BEGIN\\s+(RSA|OPENSSH|DSA|EC)\\s+PRIVATE\\s+KEY",
      desc = "私钥"
    )
  )

  for (name in names(patterns)) {
    p <- patterns[[name]]
    if (grepl(p$pattern, content_str, perl = TRUE)) {
      return(list(safe = FALSE, reason = sprintf("检测到%s", p$desc)))
    }
  }

  return(list(safe = TRUE, reason = "检查通过"))
}

# 检查文件大小
check_file_size <- function(filepath) {
  if (!file.exists(filepath)) {
    return(list(ok = TRUE, size = 0))
  }
  size <- file.info(filepath)$size
  # 警告大于 10MB 的文件
  if (size > 10 * 1024 * 1024) {
    return(list(ok = FALSE, size = size, reason = "文件超过 10MB"))
  }
  return(list(ok = TRUE, size = size))
}

# 记录日志
log_hook <- function(project_dir, hook_type, tool, filepath, status, message) {
  data_dir <- file.path(project_dir, "data")
  log_file <- file.path(data_dir, "hook_log.csv")

  log_entry <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    hook_type = hook_type,
    tool = tool,
    filepath = filepath,
    status = status,
    message = message,
    stringsAsFactors = FALSE
  )

  if (file.exists(log_file)) {
    write.table(log_entry, log_file, append = TRUE, sep = ",",
                row.names = FALSE, col.names = FALSE)
  } else {
    write.table(log_entry, log_file, append = FALSE, sep = ",",
                row.names = FALSE, col.names = TRUE)
  }
}

# NULL 默认值操作符
`%||%` <- function(x, y) if (is.null(x)) y else x

main <- function() {
  # 从环境变量获取参数
  filepath <- get_env("FILEPATH", "")
  tool <- get_env("TOOL", "Unknown")
  project_dir <- get_env("CLAUDE_PROJECT_DIR", getwd())

  if (filepath == "") {
    cat("\n⚠️  PreToolUse: 未指定文件路径\n")
    log_hook(project_dir, "PreToolUse", tool, "", "warning", "未指定文件路径")
    invisible(0)
    return()
  }

  cat(sprintf("\n🔍 PreToolUse Hook: %s\n", tool))
  cat(sprintf("   文件: %s\n", filepath))

  # 检查文件大小
  size_check <- check_file_size(filepath)
  if (!size_check$ok) {
    msg <- sprintf("文件过大: %s", size_check$reason)
    cat(sprintf("   ❌ %s\n", msg))
    log_hook(project_dir, "PreToolUse", tool, filepath, "blocked", msg)
    invisible(2)  # 阻止操作
    return()
  }

  # 检查敏感信息
  sensitive_check <- check_sensitive_info(filepath)
  if (!sensitive_check$safe) {
    cat(sprintf("   ⚠️  %s\n", sensitive_check$reason))
    cat("   🛡️  继续执行，但请注意安全风险\n")
    log_hook(project_dir, "PreToolUse", tool, filepath, "warning", sensitive_check$reason)
  } else {
    cat(sprintf("   ✅ %s\n", sensitive_check$reason))
    log_hook(project_dir, "PreToolUse", tool, filepath, "allowed", "检查通过")
  }

  # 更新 stats.json
  json_file <- file.path(project_dir, "data", "stats.json")
  if (file.exists(json_file)) {
    stats <- fromJSON(json_file)
    stats$hooks_triggered$PreToolUse <- (stats$hooks_triggered$PreToolUse %||% 0) + 1
    write_json(stats, json_file, pretty = TRUE, auto_unbox = TRUE)
  }

  cat("\n")
  invisible(0)  # 允许操作
}

main()
