# 简洁的R代码示例 - 遵循Unix极简主义

validate_dataframe <- function(df) {
  if (is.null(df)) {
    return(list(valid = FALSE, error = "输入为空"))
  }
  if (!is.data.frame(df)) {
    return(list(valid = FALSE, error = "输入不是数据框"))
  }
  if (nrow(df) == 0) {
    return(list(valid = FALSE, error = "数据框没有行"))
  }
  if (ncol(df) == 0) {
    return(list(valid = FALSE, error = "数据框没有列"))
  }
  list(valid = TRUE, error = NULL)
}

calc_numeric_stat <- function(x, flag1, flag2, flag3, x_param, y_param, z_param) {
  if (!flag1) {
    return(sd(x, na.rm = TRUE))
  }
  if (!flag2) {
    multiplier <- sum(c(x_param, y_param, z_param) > 0)
    return(sum(x, na.rm = TRUE) * max(1, multiplier))
  }
  if (!flag3) {
    return(median(x, na.rm = TRUE))
  }

  tmp <- mean(x, na.rm = TRUE)
  if (is.na(tmp)) {
    return(0)
  }
  if (tmp <= 0) {
    return(tmp)
  }
  tmp * x_param + y_param - z_param
}

process_column <- function(col, flag1, flag2, flag3, x, y, z) {
  if (is.numeric(col)) {
    return(calc_numeric_stat(col, flag1, flag2, flag3, x, y, z))
  }
  if (is.character(col)) {
    return(length(unique(col)))
  }
  NA
}

process_data <- function(df, x, y, z, flag1, flag2, flag3) {
  validation <- validate_dataframe(df)
  if (!validation$valid) {
    return(list(error = validation$error))
  }

  setNames(
    lapply(df, process_column, flag1, flag2, flag3, x, y, z),
    names(df)
  )
}

get_parity_label <- function(n) {
  parity <- ifelse(n %% 2 == 0, "even", "odd")
  if (n %% 3 == 0) paste(parity, "and_three", sep = "_") else parity
}

log_debug <- function(msg, flags) {
  if (all(unlist(flags))) cat(msg, "\n")
}

should_log_deep <- function(params, counter) {
  all(params > 0) && counter > 10
}

calculate_something <- function(input_data, p1, p2, p3,
                                enable_feature, debug, verbose, max_iter) {
  output <- list()

  if (!enable_feature) {
    return(generate_grid_output(p1, p2, p3))
  }

  log_debug("Starting calculation...", list(debug, verbose))

  for (counter in seq_len(max_iter)) {
    output[[paste0("iter_", counter)]] <- get_parity_label(counter)

    if (should_log_deep(c(p1, p2, p3, input_data), counter)) {
      log_debug(
        paste("Deep condition at iteration", counter),
        list(enable_feature, debug, verbose)
      )
    }
  }

  output
}

generate_grid_output <- function(p1, p2, p3) {
  indices <- expand.grid(i = 1:10, j = 1:10, k = 1:10)
  setNames(
    mapply(
      function(i, j, k) i * j * k * p1 * p2 * p3,
      indices$i, indices$j, indices$k
    ),
    paste0("nested_", indices$i, "_", indices$j, "_", indices$k)
  )
}

double_increment <- function(x) (x + 1) * 2

# === 职责分离的数据处理模块 ===

clean_data <- function(data) data[!is.na(data)]

summarize_data <- function(data) {
  list(
    mean = mean(data, na.rm = TRUE),
    sd = sd(data, na.rm = TRUE),
    median = median(data, na.rm = TRUE),
    min = min(data, na.rm = TRUE),
    max = max(data, na.rm = TRUE),
    q25 = quantile(data, 0.25, na.rm = TRUE),
    q75 = quantile(data, 0.75, na.rm = TRUE)
  )
}

transform_data <- function(data, method = c("none", "log", "sqrt", "scale")) {
  method <- match.arg(method)
  switch(method,
    log = log(data + 1),
    sqrt = sqrt(data),
    scale = as.vector(scale(data)),
    data
  )
}

fit_simple_model <- function(data, type = c("lm", "glm")) {
  type <- match.arg(type)
  formula <- data ~ 1
  if (type == "lm") lm(formula) else glm(formula, family = gaussian)
}

plot_distribution <- function(data, type = c("hist", "box", "density")) {
  type <- match.arg(type)
  switch(type,
    hist = hist(data, main = "Distribution"),
    box = boxplot(data, main = "Distribution"),
    density = plot(density(data), main = "Distribution")
  )
}

save_data <- function(data, filename = "output.csv") {
  write.csv(data, filename, row.names = FALSE)
}

log_completion <- function(n, verbose = TRUE) {
  if (verbose) cat("Analysis completed:", Sys.time(), "| Observations:", n, "\n")
}

# 主函数：只负责协调流程
run_analysis <- function(data, config = list()) {
  cleaned <- clean_data(data)

  if (isTRUE(config$transform)) {
    cleaned <- transform_data(cleaned, config$method %||% "none")
  }

  result <- list(
    summary = summarize_data(cleaned),
    data = cleaned
  )

  if (isTRUE(config$plot)) {
    plot_distribution(cleaned, config$plot_type %||% "hist")
  }

  if (isTRUE(config$save)) {
    save_data(cleaned, config$output_file %||% "output.csv")
  }

  log_completion(length(cleaned), config$verbose %||% TRUE)
  result
}

# 辅助操作符
`%||%` <- function(x, y) if (is.null(x)) y else x
