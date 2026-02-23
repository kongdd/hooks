#!/usr/bin/env Rscript
# PostToolUse Hook - 工具使用后执行
# 用途：格式化代码、生成报告、记录日志

suppressPackageStartupMessages(library(jsonlite))

# 从环境变量获取参数
get_env <- function(name, default = NULL) {
  val <- Sys.getenv(name, unset = "")
  if (val == "") default else val
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

# 格式化 R 文件（如果 styler 可用）
format_r_file <- function(filepath) {
  ext <- tolower(tools::file_ext(filepath))
  if (!(ext %in% c("r", "rmd"))) {
    return(list(formatted = FALSE, reason = "非 R 文件"))
  }

  # 检查 styler 包是否安装
  styler_available <- suppressWarnings(
    tryCatch({
      library(styler, logical.return = TRUE, quietly = TRUE)
    }, error = function(e) FALSE)
  )

  if (!styler_available) {
    return(list(formatted = FALSE, reason = "styler 包未安装"))
  }

  tryCatch({
    styler::style_file(filepath)
    return(list(formatted = TRUE, reason = "格式化完成"))
  }, error = function(e) {
    return(list(formatted = FALSE, reason = sprintf("格式化失败: %s", e$message)))
  })
}

# 分析文件变化
analyze_file_change <- function(filepath) {
  if (!file.exists(filepath)) {
    return(list(exists = FALSE, lines = 0))
  }

  lines <- length(readLines(filepath, warn = FALSE))
  info <- file.info(filepath)

  return(list(
    exists = TRUE,
    lines = lines,
    size = info$size,
    mtime = format(info$mtime, "%Y-%m-%d %H:%M:%S")
  ))
}

# NULL 默认值操作符
`%||%` <- function(x, y) if (is.null(x)) y else x

main <- function() {
  # 从环境变量获取参数
  filepath <- get_env("FILEPATH", "")
  tool <- get_env("TOOL", "Unknown")
  project_dir <- get_env("CLAUDE_PROJECT_DIR", getwd())

  if (filepath == "") {
    log_hook(project_dir, "PostToolUse", tool, "", "skipped", "未指定文件路径")
    invisible(0)
    return()
  }

  cat(sprintf("\n📝 PostToolUse Hook: %s\n", tool))
  cat(sprintf("   文件: %s\n", filepath))

  # 分析文件
  analysis <- analyze_file_change(filepath)
  if (analysis$exists) {
    cat(sprintf("   📊 行数: %d | 大小: %.2f KB\n",
                analysis$lines, analysis$size / 1024))
  }

  # 格式化 R 文件
  ext <- tolower(tools::file_ext(filepath))
  if (ext %in% c("r", "rmd")) {
    cat("   🔧 尝试格式化 R 文件...\n")
    result <- format_r_file(filepath)
    if (result$formatted) {
      cat(sprintf("   ✅ %s\n", result$reason))
      log_hook(project_dir, "PostToolUse", tool, filepath, "formatted", result$reason)
    } else {
      cat(sprintf("   ℹ️  %s\n", result$reason))
      log_hook(project_dir, "PostToolUse", tool, filepath, "info", result$reason)
    }
  }

  # 更新 stats.json
  json_file <- file.path(project_dir, "data", "stats.json")
  if (file.exists(json_file)) {
    stats <- fromJSON(json_file)
    stats$files_modified <- (stats$files_modified %||% 0) + 1
    stats$hooks_triggered$PostToolUse <- (stats$hooks_triggered$PostToolUse %||% 0) + 1

    # 更新文件列表
    if (ext == "r" || ext == "rmd") {
      if (!(basename(filepath) %in% stats$r_files)) {
        stats$r_files <- c(stats$r_files, basename(filepath))
      }
    }

    write_json(stats, json_file, pretty = TRUE, auto_unbox = TRUE)
  }

  # 如果修改的是 CSV，生成简要统计
  if (ext == "csv" && file.exists(filepath)) {
    tryCatch({
      df <- read.csv(filepath, nrows = 100)  # 只读前100行
      cat(sprintf("   📈 CSV 预览: %d 列, %d+ 行\n", ncol(df), nrow(df)))
      log_hook(project_dir, "PostToolUse", tool, filepath, "analyzed",
               sprintf("%d cols, %d rows", ncol(df), nrow(df)))
    }, error = function(e) {
      log_hook(project_dir, "PostToolUse", tool, filepath, "error", e$message)
    })
  }

  cat("\n")
  invisible(0)
}

main()
