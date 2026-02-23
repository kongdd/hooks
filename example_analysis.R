# Example R Analysis
# This is a sample R script to test PostToolUse hook

library(jsonlite)

# Load data
data <- read.csv("test_data.csv")

# Summary
summary(data)

# Calculate mean
mean_value <- mean(data$value)
cat(sprintf("Mean value: %.2f\n", mean_value))
