#### Robustness: duplicates, recipient words and split-to-split variation ####
# Spambase has exact duplicate emails, and it comes from one mailbox whose recipient-specific
# words (RECIPIENT_WORDS in R/evaluation.R) help separate spam from that person's mail.
# This script measures both effects on the random forest over 10 random splits.
# Uses `data`, the split and the forest from scripts/01_model_comparison.R.

N_SPLITS <- 10

#### Duplicates in the data and across the main split ####
keep <- first_occurrence(data)
key_cols <- setdiff(names(data), "spam")
labels_per_vector <- tapply(data$spam, do.call(paste, c(unname(as.list(data[key_cols])), sep = "|")),
                            function(s) length(unique(s)))
dup_in_train <- copy_in_training(train_df, valid_df)
forest_correct <- as.character(forest_prediction) == as.character(valid_df$spam)

#### Random forest over N_SPLITS splits, three versions of the data ####
deduped <- data[keep, ]
variants <- list(
  "All emails, all features"                   = list(data = data, drop = character(0)),
  "Duplicates removed"                         = list(data = deduped, drop = character(0)),
  "Duplicates removed, no recipient words"     = list(data = deduped, drop = RECIPIENT_WORDS)
)

evaluate_split <- function(d, drop, seed) {
  set.seed(seed)
  idx <- createDataPartition(factor(d$spam), p = 0.6, list = FALSE)
  tr <- d[idx, setdiff(names(d), drop)]
  va <- d[-idx, setdiff(names(d), drop)]
  rf <- randomForest(factor(spam) ~ ., data = tr)
  p <- predict(rf, newdata = va, type = "prob")[, "1"]
  t1 <- budget_threshold(rf$votes[, "1"], tr$spam, 0.01)
  c(accuracy = mean((p > 0.5) == va$spam),
    fpr_at_half = rates_at(p, va$spam, 0.5)[["false_positive_rate"]],
    rates_at(p, va$spam, t1))
}

runs <- do.call(rbind, lapply(names(variants), function(v) {
  out <- t(vapply(seq_len(N_SPLITS), function(s)
    evaluate_split(variants[[v]]$data, variants[[v]]$drop, 1000 + s), numeric(4)))
  data.frame(variant = v, split = seq_len(N_SPLITS), out, row.names = NULL)
}))
write_csv(runs, "outputs/robustness_runs.csv")

summ <- do.call(rbind, lapply(names(variants), function(v) {
  r <- runs[runs$variant == v, ]
  ms <- function(x) sprintf("%s ± %s", pct(mean(x)), pct(sd(x)))
  data.frame(`Version of the data` = v, Emails = nrow(variants[[v]]$data),
             Features = ncol(variants[[v]]$data) - 1 - length(variants[[v]]$drop),
             Accuracy = ms(r$accuracy), `False-positive rate at 0.5` = ms(r$fpr_at_half),
             `Spam caught at a 1% budget` = ms(r$spam_caught),
             `Realized false-positive rate` = ms(r$false_positive_rate),
             check.names = FALSE, row.names = NULL)
}))

report_add(
  "\n## 3. Robustness\n\n",
  sprintf("**Duplicates.** %s of the %s emails repeat an earlier email's feature vector exactly ",
          format(sum(!keep), big.mark = ","), format(nrow(data), big.mark = ",")),
  sprintf("(%s distinct vectors; %d of them appear with both labels). ",
          format(sum(keep), big.mark = ","), sum(labels_per_vector > 1)),
  sprintf("In the main split, %d of the %s validation emails (%s%%) have an exact copy in training. ",
          sum(dup_in_train), format(nrow(valid_df), big.mark = ","), pct(mean(dup_in_train), 1)),
  sprintf("The random forest is right on %s%% of those and %s%% of the rest.\n\n",
          pct(mean(forest_correct[dup_in_train])), pct(mean(forest_correct[!dup_in_train]))),
  sprintf("**Recipient words.** Spambase comes from one mailbox. The last row drops %d words that ",
          length(RECIPIENT_WORDS)),
  "identify that recipient rather than spam (", paste0("`", sub("word_freq_", "", RECIPIENT_WORDS), "`", collapse = ", "),
  "), to estimate how the filter would do on someone else's mail.\n\n",
  sprintf("**Random forest over %d random stratified 60/40 splits** (mean ± standard deviation). ", N_SPLITS),
  "The 1% budget threshold is chosen from the out-of-bag votes on the training rows of each split.\n\n",
  paste(md_table(summ), collapse = "\n"), "\n"
)
