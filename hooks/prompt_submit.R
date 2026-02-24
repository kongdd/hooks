#!/usr/bin/env Rscript
# UserPromptSubmit Hook - 用户提交 prompt 时触发

suppressMessages(library(jsonlite))

# === 约定 ===
# cat() / message() -> stderr (日志)
# return_json()     -> stdout (返回给 Claude)

log_stderr <- function(fmt, ...) cat(sprintf(fmt, ...), file = stderr())

return_json <- function(data) {
  cat(toJSON(data, auto_unbox = TRUE), "\n")
}

main <- function() {
  hook_data <- fromJSON(readLines(file("stdin")))

  user_prompt <- hook_data$prompt
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # 记录日志（stderr）
  log_stderr("[Hook] %s | Prompt: %.30s...\n", timestamp, user_prompt)

  # 分析并构造返回数据
  additional_context <- ""

  if (grepl("(写|编写|代码|function|优化|重构)", user_prompt)) {
    additional_context <- "[规范] 遵循 Unix 哲学：Do one thing well"
    log_stderr("[Hook] 注入代码规范提示\n")
  }

  if (grepl("(解释|说明|什么是)", user_prompt)) {
    additional_context <- "[规范] 给出逐步解释和示例"
    log_stderr("[Hook] 注入解释类提示\n")
  }

  # 返回结果（stdout）
  result <- list(
    continue = TRUE,
    hookSpecificOutput = list(
      hookEventName = "UserPromptSubmit",
      additionalContext = additional_context
    )
  )

  return_json(result)
}

main()
