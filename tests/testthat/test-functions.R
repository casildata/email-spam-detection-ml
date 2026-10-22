test_that("cm_spam treats spam (1) as the positive class", {
  cm <- cm_spam(c(1, 1, 0, 0), c(1, 0, 0, 0))
  expect_equal(cm$positive, "1")
  expect_equal(unname(cm$byClass["Sensitivity"]), 1)
  expect_equal(unname(cm$byClass["Specificity"]), 2 / 3)
})

test_that("spam_metrics reports the false-positive rate as 1 - specificity", {
  m <- spam_metrics(c(1, 1, 0, 0, 1), c(1, 0, 0, 0, 1))
  expect_equal(m[["accuracy"]], 0.8)
  expect_equal(m[["sensitivity"]], 1)
  expect_equal(m[["false_positive_rate"]], 1 / 3)
})

test_that("spam_metrics accepts factor predictions such as knn() output", {
  expect_equal(spam_metrics(factor(c("1", "0")), c(1, 0))[["accuracy"]], 1)
})

test_that("max_accuracy finds a cut-off that separates the classes", {
  cut <- max_accuracy(c(0, 0, 1, 1), c(0.1, 0.2, 0.8, 0.9))
  expect_gte(cut, 0.2)
  expect_lt(cut, 0.8)
})

test_that("k-NN trained on training rows only can't match a validation email to itself", {
  set.seed(1)
  x <- matrix(rnorm(400), 200)
  y <- rep(0:1, 100)  # labels unrelated to x
  train <- 1:120
  clean <- FNN::knn(x[train, ], x[-train, ], y[train], k = 1)
  leaky <- FNN::knn(x, x[-train, ], y, k = 1)  # the 2022 mistake: validation rows in the training set
  expect_equal(mean(as.character(leaky) == y[-train]), 1)
  expect_lt(mean(as.character(clean) == y[-train]), 0.75)
})
