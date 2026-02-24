suppressPackageStartupMessages(library(jsonlite))

`%||%` <- function(x, y) if (is.null(x)) y else x

# 从stdin读取JSON输入
read_stdin <- function() {
  if (interactive()) {
    return(NULL)
  }
  lines <- readLines(file("stdin"), warn = FALSE)
  if (length(lines) == 0) {
    return(NULL)
  }
  tryCatch(fromJSON(paste(lines, collapse = "\n")), error = function(e) NULL)
}

log_stderr <- function(fmt, ...) cat(sprintf(fmt, ...), file = stderr())

# make sure return format
log_stdout <- function(data) {
  cat(jsonlite::toJSON(data, auto_unbox = TRUE), "\n")
}

# 记录钩子日志到 CSV
log_hook <- function(dir, hook_type, tool, file, status, msg) {
  entry <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    hook_type = hook_type,
    tool = tool,
    filepath = if (is.null(file) || file == "") "" else basename(file),
    status = status,
    message = msg,
    stringsAsFactors = FALSE
  )
  log_file <- file.path(dir, "data", "hook_log.csv")
  write.table(entry, log_file, append = file.exists(log_file),
              sep = ",", row.names = FALSE, col.names = !file.exists(log_file))
}

# 更新 stats.json 中的钩子计数
update_stats <- function(dir, hook_name, inc_modified = FALSE) {
  json_file <- file.path(dir, "data", "stats.json")
  if (!file.exists(json_file)) return(invisible(NULL))

  stats <- fromJSON(json_file)
  stats$hooks_triggered[[hook_name]] <- (stats$hooks_triggered[[hook_name]] %||% 0) + 1
  if (inc_modified) stats$files_modified <- (stats$files_modified %||% 0) + 1
  write_json(stats, json_file, pretty = TRUE, auto_unbox = TRUE)
}

# 从 stdin 和环境变量获取上下文
get_hook_context <- function() {
  input <- read_stdin()
  list(
    tool = input$tool %||% Sys.getenv("TOOL", "Unknown"),
    file = input$tool_input$filepath %||% input$filepath %||% Sys.getenv("FILEPATH", ""),
    input = input
  )
}

# 获取项目目录
get_project_dir <- function() Sys.getenv("CLAUDE_PROJECT_DIR", getwd())
