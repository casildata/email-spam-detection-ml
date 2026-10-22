# Evaluation helpers for a mail-filter setting: the false-positive rate (legitimate mail
# flagged as spam) is the constraint, and the share of spam caught is the goal.
# Emails are flagged when their spam score is strictly above the threshold.

# Words that identify the donor mailbox (HP Labs, a person called George, phone and
# lab codes) rather than spam. UCI's own notes call out "george" and "650" as
# indicators of non-spam for this particular mailbox; the rest are the same kind.
RECIPIENT_WORDS <- paste0("word_freq_", c("hp", "hpl", "george", "650", "lab", "labs",
                                          "telnet", "857", "85"))

# Highest threshold that flags at most `budget` (a share) of the legitimate emails
budget_threshold <- function(prob, actual, budget) {
  legit <- sort(unname(prob[actual == 0]), decreasing = TRUE)
  allowed <- floor(budget * length(legit) + 1e-9)
  if (allowed >= length(legit)) return(-Inf)
  legit[allowed + 1]
}

# Spam caught and false-positive rate when flagging scores above `threshold`
rates_at <- function(prob, actual, threshold) {
  flag <- prob > threshold
  c(spam_caught = mean(flag[actual == 1]), false_positive_rate = mean(flag[actual == 0]))
}

# ROC curve: one point per distinct score, from flagging nothing to flagging everything
roc_points <- function(prob, actual) {
  thr <- c(Inf, sort(unique(prob), decreasing = TRUE), -Inf)
  pts <- t(vapply(thr, function(t) rates_at(prob, actual, t), numeric(2)))
  data.frame(threshold = thr, pts)
}

# Area under the ROC curve (the Mann-Whitney statistic; ties count half)
roc_auc <- function(prob, actual) {
  r <- rank(prob)
  n1 <- sum(actual == 1)
  n0 <- sum(actual == 0)
  (sum(r[actual == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

# Average precision: mean precision at the rank of each spam email
average_precision <- function(prob, actual) {
  y <- actual[order(prob, decreasing = TRUE)]
  mean((cumsum(y) / seq_along(y))[y == 1])
}

# TRUE for the first row of each distinct feature vector. The label isn't part of the
# key, so a vector that appears with both labels keeps only its first row.
first_occurrence <- function(df, label = "spam") {
  !duplicated(df[, setdiff(names(df), label), drop = FALSE])
}

# TRUE for each validation row whose feature vector also appears in the training rows
copy_in_training <- function(train, valid, label = "spam") {
  f <- setdiff(names(train), label)
  key <- function(d) do.call(paste, c(unname(as.list(d[f])), sep = "|"))
  key(valid) %in% key(train)
}
