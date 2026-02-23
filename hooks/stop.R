#!/usr/bin/env Rscript
# Stop Hook - Claude 响应结束后执行
# 用途：生成会话摘要报告

suppressPackageStartupMessages(library(jsonlite))

# 从环境变量获取参数
get_env <- function(name, default = NULL) {
  val <- Sys.getenv(name, unset = "")
  if (val == "") default else val
}

# 读取日志文件
read_hook_log <- function(log_file) {
  if (!file.exists(log_file)) {
    return(NULL)
  }
  tryCatch({
    read.csv(log_file, stringsAsFactors = FALSE)
  }, error = function(e) NULL)
}

# 生成会话摘要
generate_summary <- function(stats, log_df) {
  session_start <- as.POSIXct(stats$session_start, format = "%Y-%m-%dT%H:%M:%SZ")
  session_end <- Sys.time()
  duration <- difftime(session_end, session_start, units = "mins")

  # 统计各类型 hook 触发次数
  hook_counts <- stats$hooks_triggered

  # 统计文件操作
  file_ops <- list()
  if (!is.null(log_df) && nrow(log_df) > 0) {
    file_ops <- list(
      total = nrow(log_df),
      formatted = sum(log_df$status == "formatted"),
      warnings = sum(log_df$status == "warning"),
      errors = sum(log_df$status == "error"),
      allowed = sum(log_df$status == "allowed")
    )
  }

  list(
    duration_minutes = as.numeric(duration),
    files_modified = stats$files_modified,
    hooks_triggered = hook_counts,
    file_operations = file_ops,
    r_files_count = length(stats$r_files),
    session_start = stats$session_start,
    session_end = format(session_end, "%Y-%m-%dT%H:%M:%SZ")
  )
}

# 打印摘要报告
print_summary <- function(summary) {
  cat("\n")
  cat("╔══════════════════════════════════════════════════════════════╗\n")
  cat("║           R Hooks Session Summary                            ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n")
  cat("\n")

  cat(sprintf("⏱️  会话时长: %.1f 分钟\n", summary$duration_minutes))
  cat(sprintf("📝 文件修改: %d\n", summary$files_modified))
  cat(sprintf("📄 R 文件数: %d\n", summary$r_files_count))
  cat("\n")

  cat("🔔 Hooks 触发统计:\n")
  for (name in names(summary$hooks_triggered)) {
    count <- summary$hooks_triggered[[name]]
    cat(sprintf("   • %s: %d\n", name, count))
  }
  cat("\n")

  if (length(summary$file_operations) > 0) {
    cat("📊 文件操作详情:\n")
    cat(sprintf("   • 总计: %d\n", summary$file_operations$total))
    cat(sprintf("   • 格式化: %d\n", summary$file_operations$formatted))
    cat(sprintf("   • 允许: %d\n", summary$file_operations$allowed))
    cat(sprintf("   • 警告: %d\n", summary$file_operations$warnings))
    cat(sprintf("   • 错误: %d\n", summary$file_operations$errors))
    cat("\n")
  }

  cat(sprintf("🕐 开始时间: %s\n", summary$session_start))
  cat(sprintf("🕐 结束时间: %s\n", summary$session_end))
  cat("\n")
  cat("✅ R Hooks 运行正常\n")
  cat("\n")
}

# NULL 默认值操作符
`%||%` <- function(x, y) if (is.null(x)) y else x

main <- function() {
  # 从环境变量获取参数
  project_dir <- get_env("CLAUDE_PROJECT_DIR", getwd())

  # 读取 stats.json
  json_file <- file.path(project_dir, "data", "stats.json")
  if (!file.exists(json_file)) {
    cat("⚠️  未找到 stats.json，跳过摘要生成\n")
    invisible(0)
    return()
  }

  stats <- fromJSON(json_file)

  # 更新 Stop hook 计数
  stats$hooks_triggered$Stop <- (stats$hooks_triggered$Stop %||% 0) + 1

  # 读取日志
  log_file <- file.path(project_dir, "data", "hook_log.csv")
  log_df <- read_hook_log(log_file)

  # 生成摘要
  summary <- generate_summary(stats, log_df)

  # 保存更新后的 stats
  stats$session_summary <- summary
  write_json(stats, json_file, pretty = TRUE, auto_unbox = TRUE)

  # 打印摘要
  print_summary(summary)

  invisible(0)
}

main()
