#### Libraries ####
source("R/check_packages.R")  # installs anything in r-packages.txt that's missing
suppressPackageStartupMessages({
  library(tidyverse)    # data wrangling
  library(caret)        # partitioning, preprocessing, confusion matrices
  library(forecast)     # accuracy() error measures
  library(FNN)          # k-nearest neighbours
  library(rpart)        # classification tree
  library(rpart.plot)   # tree plot
  library(randomForest) # random forest
  library(reshape)      # melt() for the heatmap
  library(neuralnet)    # artificial neural network
})

#### Functions ####
# Draw a base-graphics plot straight to a PNG (no stray Rplots.pdf under Rscript)
save_png <- function(file, draw, width = 900, height = 700) {
  png(file, width = width, height = height, res = 120)
  on.exit(dev.off())
  draw()
}

# Sweep probability cut-offs on TRAINING predictions and return the one that maximises accuracy.
# If plot_file is given, the accuracy / error curve is saved there.
max_accuracy <- function(actual, prob, plot_file = NULL) {
  actual <- factor(actual, levels = c(0, 1))
  series <- seq(0.01, 0.99, 0.01)
  accT <- vapply(series, function(cut) {
    confusionMatrix(factor(1 * (prob > cut), levels = c(0, 1)), actual)$overall[["Accuracy"]]
  }, numeric(1))
  if (!is.null(plot_file)) save_png(plot_file, function() {
    plot(accT ~ series, xlab = "Cutoff Value", ylab = "", type = "l", ylim = c(0, 1))
    lines(1 - accT ~ series, type = "l", lty = 2)
    legend("center", c("accuracy", "overall error"), lty = c(1, 2), merge = TRUE)
  })
  series[which.max(accT)]
}

# Confusion matrix with spam (1) as the positive class
cm_spam <- function(pred, actual) {
  confusionMatrix(relevel(factor(pred, levels = c(0, 1)), "1"),
                  relevel(factor(actual, levels = c(0, 1)), "1"))
}
