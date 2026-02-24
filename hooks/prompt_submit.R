#!/usr/bin/env Rscript
# UserPromptSubmit Hook - 用户提交 prompt 时触发

suppressMessages(library(jsonlite))
source(file.path(Sys.getenv("CLAUDE_PROJECT_DIR", getwd()), "R", "hooks.R"))

main <- function() {
  hook_data <- fromJSON(readLines(file("stdin")))

  user_prompt <- hook_data$prompt
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  log_stderr("[Hook] %s | Prompt: %.30s...\n", timestamp, user_prompt)

  additional_context <- ""

  if (grepl("(写|编写|代码|function|优化|重构)", user_prompt)) {
    additional_context <- "[规范] 遵循 Unix 哲学：Do one thing well"
    log_stderr("[Hook] 注入代码规范提示\n")
  }

  if (grepl("(解释|说明|什么是)", user_prompt)) {
    additional_context <- "[规范] 给出逐步解释和示例"
    log_stderr("[Hook] 注入解释类提示\n")
  }

  log_stdout(list(
    continue = TRUE,
    hookSpecificOutput = list(
      hookEventName = "UserPromptSubmit",
      additionalContext = additional_context
    )
  ))
}

main()
