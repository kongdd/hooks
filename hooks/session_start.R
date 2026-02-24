#!/usr/bin/env Rscript
# SessionStart Hook - 扫描项目，生成统计信息

suppressPackageStartupMessages(library(jsonlite))

`%||%` <- function(x, y) if (is.null(x)) y else x

log_stderr <- function(fmt, ...) cat(sprintf(fmt, ...), file = stderr())

scan_project <- function(dir) {
  old <- setwd(dir)
  on.exit(setwd(old))

  files <- list.files(".", recursive = TRUE, full.names = FALSE)
  files <- files[!grepl("^[.]|(data|hooks)[/\\]", files)]
  files <- files[!file.info(file.path(dir, files))$isdir]

  stats <- list(total = 0, types = list(), r = c(), json = c(), csv = c())

  for (f in files) {
    ext <- tolower(tools::file_ext(f))
    stats$total <- stats$total + 1
    stats$types[[ext]] <- (stats$types[[ext]] %||% 0) + 1

    if (ext %in% c("r", "rmd")) stats$r <- c(stats$r, f)
    else if (ext == "json") stats$json <- c(stats$json, f)
    else if (ext == "csv") stats$csv <- c(stats$csv, f)
  }

  stats
}

main <- function() {
  project_dir <- Sys.getenv("CLAUDE_PROJECT_DIR", getwd())
  stats <- scan_project(project_dir)

  log_stderr("\n╔══════════════════════════════════════════════════════════════╗\n")
  log_stderr("║           R Hooks Session Start                              ║\n")
  log_stderr("╚══════════════════════════════════════════════════════════════╝\n\n")

  data_dir <- file.path(project_dir, "data")
  if (!dir.exists(data_dir)) dir.create(data_dir, recursive = TRUE)

  session_data <- list(
    session_start = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
    project_dir = project_dir,
    total_files = stats$total,
    r_files = stats$r,
    json_files = stats$json,
    csv_files = stats$csv,
    file_types = stats$types,
    files_modified = 0,
    hooks_triggered = list(SessionStart = 1, PreToolUse = 0, PostToolUse = 0, Stop = 0)
  )

  json_file <- file.path(data_dir, "stats.json")
  write_json(session_data, json_file, pretty = TRUE, auto_unbox = TRUE)

  log_stderr("📁 项目目录: %s\n", project_dir)
  log_stderr("📊 文件总数: %d\n", stats$total)
  log_stderr("📄 R 文件数: %d\n", length(stats$r))
  if (length(stats$r)) log_stderr("   └─ %s\n", paste(stats$r, collapse = ", "))
  log_stderr("📄 JSON 文件数: %d\n", length(stats$json))
  log_stderr("📄 CSV 文件数: %d\n", length(stats$csv))
  log_stderr("\n✅ 统计信息已保存: %s\n\n", json_file)

  invisible(0)
}

main()
