# 混乱的R代码示例 - 用于测试代码简洁性检查
# 更新: 添加更多测试场景

process_data <- function(df, x, y, z, flag1, flag2, flag3) {
  # 这个函数做太多事情了
  result <- list()

  if (!is.null(df)) {
    if (is.data.frame(df)) {
      if (nrow(df) > 0) {
        if (ncol(df) > 0) {
          for (i in 1:ncol(df)) {
            if (is.numeric(df[[i]])) {
              if (flag1 == TRUE) {
                if (flag2 == TRUE) {
                  if (flag3 == TRUE) {
                    tmp <- mean(df[[i]], na.rm = TRUE)
                    if (!is.na(tmp)) {
                      if (tmp > 0) {
                        result[[names(df)[i]]] <- tmp * x + y - z
                      } else {
                        result[[names(df)[i]]] <- tmp
                      }
                    } else {
                      result[[names(df)[i]]] <- 0
                    }
                  } else {
                    result[[names(df)[i]]] <- median(df[[i]], na.rm = TRUE)
                  }
                } else {
                  if (x > 0) {
                    if (y > 0) {
                      if (z > 0) {
                        result[[names(df)[i]]] <- sum(df[[i]], na.rm = TRUE) * x * y * z
                      } else {
                        result[[names(df)[i]]] <- sum(df[[i]], na.rm = TRUE) * x * y
                      }
                    } else {
                      result[[names(df)[i]]] <- sum(df[[i]], na.rm = TRUE) * x
                    }
                  } else {
                    result[[names(df)[i]]] <- sum(df[[i]], na.rm = TRUE)
                  }
                }
              } else {
                result[[names(df)[i]]] <- sd(df[[i]], na.rm = TRUE)
              }
            } else {
              if (is.character(df[[i]])) {
                result[[names(df)[i]]] <- length(unique(df[[i]]))
              } else {
                result[[names(df)[i]]] <- NA
              }
            }
          }
        } else {
          result$error <- "数据框没有列"
        }
      } else {
        result$error <- "数据框没有行"
      }
    } else {
      result$error <- "输入不是数据框"
    }
  } else {
    result$error <- "输入为空"
  }

  # 冗余的计算
  a <- 1
  b <- 2
  c <- 3
  d <- a + b + c
  e <- d * 2
  f <- e / 2
  # f 其实就是 d，完全没必要这样算

  result$extra1 <- a
  result$extra2 <- b
  result$extra3 <- c
  result$extra4 <- d
  result$extra5 <- e
  result$extra6 <- f

  return(result)
}

# 另一个混乱的函数
calculate_something <- function(input_data, parameter_one, parameter_two, parameter_three, enable_feature_flag, debug_mode, verbose_output, max_iterations) {
  # 变量命名不清晰
  x <- input_data
  p1 <- parameter_one
  p2 <- parameter_two
  p3 <- parameter_three

  output <- list()

  if (enable_feature_flag) {
    if (debug_mode) {
      if (verbose_output) {
        cat("Starting calculation...\n")
      }
    }

    counter <- 0
    while (counter < max_iterations) {
      counter <- counter + 1

      if (counter %% 2 == 0) {
        if (counter %% 3 == 0) {
          if (counter %% 5 == 0) {
            output[[paste0("iter_", counter)]] <- "special"
          } else {
            output[[paste0("iter_", counter)]] <- "even_and_three"
          }
        } else {
          output[[paste0("iter_", counter)]] <- "even"
        }
      } else {
        if (counter %% 3 == 0) {
          output[[paste0("iter_", counter)]] <- "odd_and_three"
        } else {
          output[[paste0("iter_", counter)]] <- "odd"
        }
      }

      # 深层嵌套
      if (p1 > 0) {
        if (p2 > 0) {
          if (p3 > 0) {
            if (x > 0) {
              if (counter > 10) {
                if (enable_feature_flag) {
                  if (debug_mode) {
                    if (verbose_output) {
                      cat("Deep nested condition reached at iteration", counter, "with positive values\n")
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  } else {
    for (i in 1:10) {
      for (j in 1:10) {
        for (k in 1:10) {
          output[[paste0("nested_", i, "_", j, "_", k)]] <- i * j * k * p1 * p2 * p3
        }
      }
    }
  }

  # 超长的行，不符合行宽限制 this_is_a_very_long_variable_name_that_makes_the_line_too_long_and_difficult_to_read_and_understand <- "too long"

  return(output)
}

# 重复代码
function_a <- function(x) {
  y <- x + 1
  z <- y * 2
  return(z)
}

function_b <- function(x) {
  y <- x + 1
  z <- y * 2
  return(z)
}

function_c <- function(x) {
  y <- x + 1
  z <- y * 2
  return(z)
}

# 没有单一职责的巨型函数
do_everything <- function(data, config, options, settings, parameters, flags, modes, thresholds) {
  # 1. 数据清洗
  cleaned <- data[!is.na(data), ]

  # 2. 数据分析
  analysis <- list()
  analysis$mean <- mean(cleaned, na.rm = TRUE)
  analysis$sd <- sd(cleaned, na.rm = TRUE)
  analysis$median <- median(cleaned, na.rm = TRUE)
  analysis$min <- min(cleaned, na.rm = TRUE)
  analysis$max <- max(cleaned, na.rm = TRUE)
  analysis$q25 <- quantile(cleaned, 0.25, na.rm = TRUE)
  analysis$q75 <- quantile(cleaned, 0.75, na.rm = TRUE)

  # 3. 数据转换
  if (config$transform) {
    if (config$method == "log") {
      transformed <- log(cleaned + 1)
    } else if (config$method == "sqrt") {
      transformed <- sqrt(cleaned)
    } else if (config$method == "scale") {
      transformed <- scale(cleaned)
    } else {
      transformed <- cleaned
    }
  } else {
    transformed <- cleaned
  }

  # 4. 模型拟合（不应该在这个函数里）
  if (options$fit_model) {
    if (options$model_type == "lm") {
      model <- lm(transformed ~ 1)
    } else if (options$model_type == "glm") {
      model <- glm(transformed ~ 1, family = gaussian)
    } else {
      model <- NULL
    }
  } else {
    model <- NULL
  }

  # 5. 结果可视化（也不应该在这个函数里）
  if (settings$plot) {
    if (!is.null(modes$plot_type)) {
      if (modes$plot_type == "hist") {
        hist(transformed)
      } else if (modes$plot_type == "box") {
        boxplot(transformed)
      } else if (modes$plot_type == "density") {
        plot(density(transformed))
      }
    }
  }

  # 6. 报告生成
  report <- list(
    analysis = analysis,
    transformed_data = transformed,
    model = model,
    parameters = parameters,
    flags = flags,
    thresholds = thresholds
  )

  # 7. 文件输出
  if (settings$save_output) {
    write.csv(transformed, "output.csv")
  }

  # 8. 日志记录
  if (flags$verbose) {
    cat("Analysis completed at", Sys.time(), "with", length(cleaned), "observations\n")
  }

  return(report)
}
