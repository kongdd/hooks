#!/usr/bin/env Rscript
# PreToolUse Hook - 从stdin读取数据，验证文件操作

suppressPackageStartupMessages(library(jsonlite))

`%||%` <- function(x, y) if (is.null(x)) y else x

log_stderr <- function(fmt, ...) cat(sprintf(fmt, ...), file = stderr())

# 从stdin读取JSON输入
read_stdin <- function() {
  if (interactive()) return(NULL)
  lines <- readLines(file("stdin"), warn = FALSE)
  if (length(lines) == 0) return(NULL)
  tryCatch(fromJSON(paste(lines, collapse = "\n")), error = function(e) NULL)
}

log_hook <- function(dir, tool, file, status, msg) {
  entry <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    hook_type = "PreToolUse",
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
  # 从stdin读取hook数据
  input <- read_stdin()

  # 提取信息（优先stdin，其次环境变量）
  tool <- input$tool %||% Sys.getenv("TOOL", "Unknown")
  file <- input$tool_input$filepath %||% input$filepath %||% Sys.getenv("FILEPATH", "")
  dir <- Sys.getenv("CLAUDE_PROJECT_DIR", getwd())

  if (file == "") {
    log_stderr("\n⚠️  PreToolUse: 未指定文件路径\n")
    log_hook(dir, tool, "", "warning", "未指定文件路径")
    return(invisible(0))
  }

  log_stderr("\n🔍 PreToolUse: %s\n   文件: %s\n", tool, file)

  if (file.exists(file) && file.info(file)$size > 10 * 1024 * 1024) {
    log_stderr("   ❌ 文件超过 10MB\n")
    log_hook(dir, tool, file, "blocked", "文件过大")
    return(invisible(2))
  }

  result <- check_sensitive(file)
  log_stderr("   %s %s\n", if (result$ok) "✅" else "⚠️", result$msg)
  log_hook(dir, tool, file, if (result$ok) "allowed" else "warning", result$msg)

  json_file <- file.path(dir, "data", "stats.json")
  if (file.exists(json_file)) {
    stats <- fromJSON(json_file)
    stats$hooks_triggered$PreToolUse <- (stats$hooks_triggered$PreToolUse %||% 0) + 1
    write_json(stats, json_file, pretty = TRUE, auto_unbox = TRUE)
  }

  log_stderr("\n")
  invisible(0)
}

main()
