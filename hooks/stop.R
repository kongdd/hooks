#!/usr/bin/env Rscript
# Stop Hook - 生成会话摘要报告

suppressPackageStartupMessages(library(jsonlite))

`%||%` <- function(x, y) if (is.null(x)) y else x

main <- function() {
  dir <- Sys.getenv("CLAUDE_PROJECT_DIR", getwd())
  json_file <- file.path(dir, "data", "stats.json")

  if (!file.exists(json_file)) {
    cat("⚠️  未找到 stats.json\n")
    return(invisible(0))
  }

  stats <- fromJSON(json_file)
  stats$hooks_triggered$Stop <- (stats$hooks_triggered$Stop %||% 0) + 1

  log_file <- file.path(dir, "data", "hook_log.csv")
  log_df <- if (file.exists(log_file)) tryCatch(read.csv(log_file), error = function(e) NULL) else NULL

  duration <- as.numeric(difftime(Sys.time(),
    as.POSIXct(stats$session_start, format = "%Y-%m-%dT%H:%M:%SZ"), units = "mins"))

  ops <- if (!is.null(log_df) && nrow(log_df) > 0) {
    list(
      total = nrow(log_df),
      formatted = sum(log_df$status == "formatted"),
      warnings = sum(log_df$status == "warning"),
      errors = sum(log_df$status == "error"),
      allowed = sum(log_df$status == "allowed")
    )
  } else list()

  summary <- list(
    duration = duration,
    modified = stats$files_modified,
    hooks = stats$hooks_triggered,
    ops = ops,
    r_count = length(stats$r_files),
    start = stats$session_start,
    end = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
  )

  stats$session_summary <- summary
  write_json(stats, json_file, pretty = TRUE, auto_unbox = TRUE)

  cat("\n╔══════════════════════════════════════════════════════════════╗\n")
  cat("║           R Hooks Session Summary                            ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n\n")
  cat(sprintf("⏱️  会话时长: %.1f 分钟\n", summary$duration))
  cat(sprintf("📝 文件修改: %d\n", summary$modified))
  cat(sprintf("📄 R 文件数: %d\n\n", summary$r_count))

  cat("🔔 Hooks 触发统计:\n")
  for (n in names(summary$hooks)) cat(sprintf("   • %s: %d\n", n, summary$hooks[[n]]))

  if (length(summary$ops)) {
    cat("\n📊 文件操作详情:\n")
    cat(sprintf("   • 总计: %d\n", summary$ops$total))
    cat(sprintf("   • 格式化: %d\n", summary$ops$formatted))
    cat(sprintf("   • 允许: %d\n", summary$ops$allowed))
    cat(sprintf("   • 警告: %d\n", summary$ops$warnings))
    cat(sprintf("   • 错误: %d\n", summary$ops$errors))
  }

  cat(sprintf("\n🕐 %s → %s\n", summary$start, summary$end))
  cat("\n✅ R Hooks 运行正常\n\n")

  invisible(0)
}

main()
