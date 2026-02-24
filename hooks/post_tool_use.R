#!/usr/bin/env Rscript
# PostToolUse Hook - 从stdin读取数据，格式化代码

suppressPackageStartupMessages(library(jsonlite))
source(file.path(Sys.getenv("CLAUDE_PROJECT_DIR", getwd()), "R", "hooks.R"))

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

# 检查函数长度
check_fn_len <- function(lines) {
  in_fn <- FALSE
  fn_start <- 0
  fn_name <- ""
  brace_count <- 0
  issues <- c()
  deduct <- 0

  for (i in seq_along(lines)) {
    line <- lines[i]
    trimmed <- trimws(line)

    if (grepl("<-\\s*function\\s*\\(", line)) {
      in_fn <- TRUE
      fn_start <- i
      fn_name <- sub("^\\s*([a-zA-Z0-9_.]+).*", "\\1", line)
      brace_count <- 0
    }

    if (!in_fn) next

    brace_count <- brace_count + sum(gregexpr("{", line, fixed = TRUE)[[1]] > 0)
    brace_count <- brace_count - sum(gregexpr("}", line, fixed = TRUE)[[1]] > 0)

    if ((brace_count <= 0 && grepl("^}", trimmed)) || i == length(lines)) {
      fn_len <- i - fn_start
      if (fn_len > 50) {
        deduct <- deduct + 10
        issues <- c(issues, sprintf("函数 '%s' 过长: %d 行", fn_name, fn_len))
      } else if (fn_len > 30) {
        deduct <- deduct + 5
        issues <- c(issues, sprintf("函数 '%s' 偏长: %d 行", fn_name, fn_len))
      }
      in_fn <- FALSE
    }
  }
  list(deduct = deduct, issues = issues)
}

# 检查嵌套深度
check_nest <- function(lines) {
  max_indent <- 0
  for (line in lines) {
    trimmed <- trimws(line)
    if (trimmed == "" || grepl("^#", trimmed)) next
    indent <- nchar(line) - nchar(sub("^ +", "", line))
    max_indent <- max(max_indent, indent %/% 2)
  }
  if (max_indent > 6) return(list(deduct = 10, issues = sprintf("嵌套过深: 约 %d 层", max_indent %/% 2)))
  if (max_indent > 4) return(list(deduct = 5, issues = sprintf("嵌套较深: 约 %d 层", max_indent %/% 2)))
  list(deduct = 0, issues = character())
}

# 检查行宽
check_width <- function(lines) {
  long_lines <- sum(sapply(lines, nchar) > 100)
  if (long_lines == 0) return(list(deduct = 0, issues = character()))
  list(deduct = min(long_lines * 2, 20), issues = sprintf("%d 行超过 100 字符", long_lines))
}

# 检查早返回
check_return <- function(lines) {
  if (length(lines) <= 50) return(list(deduct = 0, issues = character()))
  has_return <- any(grepl("^\\s*return\\s*\\(|^\\s*invisible\\s*\\(", lines))
  if (has_return) return(list(deduct = 0, issues = character()))
  list(deduct = 5, issues = "建议使用早返回模式")
}

# 检查参数数量
check_params <- function(lines) {
  issues <- character()
  deduct <- 0
  for (line in lines) {
    if (!grepl("<-\\s*function\\s*\\(", line)) next
    params <- gsub(".*function\\s*\\(([^)]+).*", "\\1", line)
    n <- length(strsplit(params, ",")[[1]])
    if (n <= 5) next
    deduct <- deduct + 5
    issues <- c(issues, sprintf("函数参数过多: %d 个", n))
  }
  list(deduct = deduct, issues = issues)
}

# 代码简洁性分析
analyze_code <- function(f) {
  lines <- readLines(f, warn = FALSE)
  issues <- c()
  score <- 100

  for (check in list(check_fn_len, check_nest, check_width, check_return, check_params)) {
    r <- check(lines)
    score <- score - r$deduct
    issues <- c(issues, r$issues)
  }

  list(score = max(0, score), issues = issues,
       level = if (score >= 80) "优秀" else if (score >= 60) "良好" else "需改进")
}

main <- function() {
  ctx <- get_hook_context()
  dir <- get_project_dir()

  if (ctx$file == "") {
    log_hook(dir, "PostToolUse", ctx$tool, "", "skipped", "未指定文件路径")
    return(invisible(0))
  }

  log_stderr("\n📝 PostToolUse: %s\n   文件: %s\n", ctx$tool, ctx$file)

  if (file.exists(ctx$file)) {
    lines <- length(readLines(ctx$file, warn = FALSE))
    size <- file.info(ctx$file)$size / 1024
    log_stderr("   📊 行数: %d | 大小: %.2f KB\n", lines, size)
  }

  ext <- tolower(tools::file_ext(ctx$file))

  if (ext %in% c("r", "rmd")) {
    log_stderr("   🔧 尝试格式化...\n")
    r <- format_r(ctx$file)
    log_stderr("   %s %s\n", if (r$ok) "✅" else "ℹ️", r$msg)
    log_hook(dir, "PostToolUse", ctx$tool, ctx$file, if (r$ok) "formatted" else "info", r$msg)
  }

  if (ext == "csv" && file.exists(ctx$file)) {
    tryCatch({
      df <- read.csv(ctx$file, nrows = 100)
      log_stderr("   📈 CSV: %d 列, %d+ 行\n", ncol(df), nrow(df))
      log_hook(dir, "PostToolUse", ctx$tool, ctx$file, "analyzed", sprintf("%d cols, %d rows", ncol(df), nrow(df)))
    }, error = function(e) log_hook(dir, "PostToolUse", ctx$tool, ctx$file, "error", e$message))
  }

  if (ext %in% c("r", "rmd") && file.exists(ctx$file)) {
    log_stderr("\n   📐 代码简洁性分析:\n")
    analysis <- analyze_code(ctx$file)
    icon <- if (analysis$score >= 80) "✅" else if (analysis$score >= 60) "⚠️" else "❌"
    log_stderr("   %s 评分: %d/100 (%s)\n", icon, analysis$score, analysis$level)

    if (length(analysis$issues) > 0) {
      log_stderr("   主要问题:\n")
      for (issue in head(analysis$issues, 3)) log_stderr("   • %s\n", issue)
    }

    log_hook(dir, "PostToolUse", ctx$tool, ctx$file, "simplification",
             sprintf("score: %d, issues: %d", analysis$score, length(analysis$issues)))
  }

  update_stats(dir, "PostToolUse", inc_modified = TRUE)

  log_stderr("\n")
  invisible(0)
}

main()
