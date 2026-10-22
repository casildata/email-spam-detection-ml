legit_scores <- seq(0.1, 1, by = 0.1)  # ten legitimate emails
spam_scores  <- c(0.95, 0.85, 0.75, 0.05)
prob   <- c(legit_scores, spam_scores)
actual <- c(rep(0, 10), rep(1, 4))

test_that("budget_threshold flags at most the budgeted share of legitimate email", {
  t10 <- budget_threshold(prob, actual, 0.10)
  expect_equal(t10, 0.9)
  expect_equal(rates_at(prob, actual, t10)[["false_positive_rate"]], 0.1)
  expect_equal(rates_at(prob, actual, budget_threshold(prob, actual, 0))[["false_positive_rate"]], 0)
  expect_equal(budget_threshold(prob, actual, 1), -Inf)
})

test_that("budget_threshold stays within budget when scores tie", {
  tied <- c(rep(0.9, 3), rep(0.1, 7))
  t <- budget_threshold(tied, rep(0, 10), 0.2)
  expect_lte(rates_at(tied, rep(0, 10), t)[["false_positive_rate"]], 0.2)
})

test_that("budget_threshold returns a plain number for named scores", {
  named <- setNames(prob, paste0("row", seq_along(prob)))
  expect_null(names(budget_threshold(named, actual, 0.1)))
})

test_that("rates_at counts spam caught and legitimate mail flagged", {
  r <- rates_at(prob, actual, 0.8)
  expect_equal(r[["spam_caught"]], 0.5)
  expect_equal(r[["false_positive_rate"]], 0.2)
})

test_that("roc_points runs from flagging nothing to flagging everything", {
  pts <- roc_points(prob, actual)
  expect_equal(unlist(pts[1, c("spam_caught", "false_positive_rate")], use.names = FALSE), c(0, 0))
  expect_equal(unlist(pts[nrow(pts), c("spam_caught", "false_positive_rate")], use.names = FALSE), c(1, 1))
  expect_false(is.unsorted(pts$false_positive_rate))
})

test_that("roc_auc matches perfect, reversed and tied rankings", {
  expect_equal(roc_auc(c(0.1, 0.2, 0.8, 0.9), c(0, 0, 1, 1)), 1)
  expect_equal(roc_auc(c(0.9, 0.8, 0.2, 0.1), c(0, 0, 1, 1)), 0)
  expect_equal(roc_auc(c(0.5, 0.5, 0.5, 0.5), c(0, 0, 1, 1)), 0.5)
})

test_that("average_precision is the mean precision at each spam email", {
  expect_equal(average_precision(c(0.9, 0.8, 0.7), c(1, 1, 0)), 1)
  expect_equal(average_precision(c(0.9, 0.8, 0.7), c(1, 0, 1)), (1 + 2 / 3) / 2)
})

test_that("first_occurrence keeps one row per feature vector, ignoring the label", {
  d <- data.frame(a = c(1, 1, 2, 1), b = c(0, 0, 0, 0), spam = c(1, 1, 0, 0))
  expect_equal(first_occurrence(d), c(TRUE, FALSE, TRUE, FALSE))
})

test_that("copy_in_training finds validation rows that also appear in training", {
  tr <- data.frame(a = c(1, 2), b = c(3, 4), spam = c(1, 0))
  va <- data.frame(a = c(1, 5), b = c(3, 4), spam = c(0, 0))
  expect_equal(copy_in_training(tr, va), c(TRUE, FALSE))
})

test_that("recipient words are real Spambase columns", {
  cols <- names(read.csv(file.path("..", "..", "data", "raw", "spambase.csv"), nrows = 1,
                         check.names = FALSE))
  expect_true(all(RECIPIENT_WORDS %in% cols))
})
