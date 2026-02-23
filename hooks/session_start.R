#!/usr/bin/env Rscript
# SessionStart Hook - 会话开始时执行
# 用途：扫描项目，生成初始统计信息

suppressPackageStartupMessages(library(jsonlite))

# 从环境变量获取参数
get_env <- function(name, default = NULL) {
  val <- Sys.getenv(name, unset = "")
  if (val == "") default else val
}

# 扫描项目文件
scan_project <- function(project_dir) {
  # 标准化路径
  project_dir <- normalizePath(project_dir, winslash = "/", mustWork = FALSE)

  # 切换到项目目录并获取相对路径文件列表
  old_wd <- getwd()
  on.exit(setwd(old_wd))
  setwd(project_dir)

  # 获取所有文件（排除隐藏目录）
  all_files <- list.files(".", recursive = TRUE, full.names = FALSE, all.files = FALSE)

  # 排除特定目录（使用 startsWith 避免正则问题）
  exclude_dirs <- c(".", "data/", "hooks/", "data\\", "hooks\\")

  files <- all_files[!sapply(all_files, function(f) {
    any(sapply(exclude_dirs, function(d) startsWith(f, d)))
  })]

  # 只保留文件（排除目录）- 需要完整路径检查
  full_paths <- file.path(project_dir, files)
  is_file <- !file.info(full_paths)$isdir
  files <- files[is_file]
  full_paths <- full_paths[is_file]

  stats <- list(
    total_files = length(files),
    file_types = list(),
    r_files = character(),
    json_files = character(),
    csv_files = character(),
    other_files = character()
  )

  for (f in files) {
    ext <- tolower(tools::file_ext(f))
    basename_f <- basename(f)
    if (ext == "r" || ext == "rmd") {
      stats$r_files <- c(stats$r_files, f)
    } else if (ext == "json") {
      stats$json_files <- c(stats$json_files, f)
    } else if (ext == "csv") {
      stats$csv_files <- c(stats$csv_files, f)
    } else {
      stats$other_files <- c(stats$other_files, f)
    }
    stats$file_types[[ext]] <- (stats$file_types[[ext]] %||% 0) + 1
  }

  return(stats)
}

# NULL 默认值操作符
`%||%` <- function(x, y) if (is.null(x)) y else x

main <- function() {
  # 优先从环境变量获取，否则使用当前目录
  project_dir <- get_env("CLAUDE_PROJECT_DIR", getwd())

  cat("\n")
  cat("╔══════════════════════════════════════════════════════════════╗\n")
  cat("║           R Hooks Session Start                              ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n")
  cat("\n")

  # 扫描项目
  stats <- scan_project(project_dir)

  # 创建初始统计
  session_data <- list(
    session_start = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
    project_dir = project_dir,
    total_files = stats$total_files,
    r_files = stats$r_files,
    json_files = stats$json_files,
    csv_files = stats$csv_files,
    file_types = stats$file_types,
    files_modified = 0,
    lines_added = 0,
    lines_removed = 0,
    hooks_triggered = list(
      SessionStart = 1,
      PreToolUse = 0,
      PostToolUse = 0,
      Stop = 0
    )
  )

  # 保存到 JSON
  data_dir <- file.path(project_dir, "data")
  if (!dir.exists(data_dir)) {
    dir.create(data_dir, recursive = TRUE)
  }

  json_file <- file.path(data_dir, "stats.json")
  write_json(session_data, json_file, pretty = TRUE, auto_unbox = TRUE)

  # 输出欢迎信息
  cat(sprintf("📁 项目目录: %s\n", project_dir))
  cat(sprintf("📊 文件总数: %d\n", stats$total_files))
  cat(sprintf("📄 R 文件数: %d\n", length(stats$r_files)))
  if (length(stats$r_files) > 0) {
    cat(sprintf("   └─ %s\n", paste(stats$r_files, collapse = ", ")))
  }
  cat(sprintf("📄 JSON 文件数: %d\n", length(stats$json_files)))
  cat(sprintf("📄 CSV 文件数: %d\n", length(stats$csv_files)))
  cat("\n")
  cat(sprintf("✅ 统计信息已保存到: %s\n", json_file))
  cat("\n")

  invisible(0)
}

main()
