#!/usr/bin/env Rscript
# PostToolUse Hook - 格式化代码、生成报告、记录日志

suppressPackageStartupMessages(library(jsonlite))

`%||%` <- function(x, y) if (is.null(x)) y else x

log_hook <- function(dir, tool, file, status, msg) {
  entry <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    hook_type = "PostToolUse",
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

format_r <- function(f) {
  ext <- tolower(tools::file_ext(f))
  if (!ext %in% c("r", "rmd")) return(list(ok = FALSE, msg = "非 R 文件"))

  if (!requireNamespace("styler", quietly = TRUE)) {
    return(list(ok = FALSE, msg = "styler 未安装"))
  }

  tryCatch({
    styler::style_file(f)
    list(ok = TRUE, msg = "格式化完成")
  }, error = function(e) list(ok = FALSE, msg = sprintf("格式化失败: %s", e$message)))
}

main <- function() {
  file <- Sys.getenv("FILEPATH", "")
  tool <- Sys.getenv("TOOL", "Unknown")
  dir <- Sys.getenv("CLAUDE_PROJECT_DIR", getwd())

  if (file == "") {
    log_hook(dir, tool, "", "skipped", "未指定文件路径")
    return(invisible(0))
  }

  cat(sprintf("\n📝 PostToolUse: %s\n   文件: %s\n", tool, file))

  if (file.exists(file)) {
    lines <- length(readLines(file, warn = FALSE))
    size <- file.info(file)$size / 1024
    cat(sprintf("   📊 行数: %d | 大小: %.2f KB\n", lines, size))
  }

  ext <- tolower(tools::file_ext(file))

  if (ext %in% c("r", "rmd")) {
    cat("   🔧 尝试格式化...\n")
    r <- format_r(file)
    cat(sprintf("   %s %s\n", if (r$ok) "✅" else "ℹ️", r$msg))
    log_hook(dir, tool, file, if (r$ok) "formatted" else "info", r$msg)
  }

  if (ext == "csv" && file.exists(file)) {
    tryCatch({
      df <- read.csv(file, nrows = 100)
      cat(sprintf("   📈 CSV: %d 列, %d+ 行\n", ncol(df), nrow(df)))
      log_hook(dir, tool, file, "analyzed", sprintf("%d cols, %d rows", ncol(df), nrow(df)))
    }, error = function(e) log_hook(dir, tool, file, "error", e$message))
  }

  json_file <- file.path(dir, "data", "stats.json")
  if (file.exists(json_file)) {
    stats <- fromJSON(json_file)
    stats$files_modified <- (stats$files_modified %||% 0) + 1
    stats$hooks_triggered$PostToolUse <- (stats$hooks_triggered$PostToolUse %||% 0) + 1
    if (ext %in% c("r", "rmd") && !(basename(file) %in% stats$r_files)) {
      stats$r_files <- c(stats$r_files, basename(file))
    }
    write_json(stats, json_file, pretty = TRUE, auto_unbox = TRUE)
  }

  cat("\n")
  invisible(0)
}

main()
