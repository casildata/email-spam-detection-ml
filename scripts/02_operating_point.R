#### Operating point: spam caught under a false-positive budget ####
# A mail filter is judged first by how much legitimate mail it blocks. The thresholds
# are chosen on training data only (out-of-bag votes for the random forest, 5-fold
# cross-validated probabilities for logistic regression) and applied once to the
# validation set, which plays the part of next month's mail.
# Uses the split and models from scripts/01_model_comparison.R.

BUDGETS <- c(0.01, 0.001)

# Training scores that no model saw while fitting
forest_oob <- forest$votes[, "1"]
set.seed(2)
folds_lr <- createFolds(factor(train_df$spam), k = 5)
logit_cv <- numeric(nrow(train_df))
for (f in folds_lr) {
  m <- suppressWarnings(glm(spam ~ ., data = train_df[-f, ], family = "binomial"))
  logit_cv[f] <- predict(m, newdata = train_df[f, ], type = "response")
}

models <- list(
  "Random forest"       = list(train = forest_oob, valid = forest_probability, default = 0.5),
  "Logistic regression" = list(train = logit_cv, valid = logit_valid_prob, default = cut_off_logit)
)
y_train <- train_df$spam
y_valid <- valid_df$spam
n_legit <- sum(y_valid == 0)

op <- do.call(rbind, lapply(names(models), function(name) {
  m <- models[[name]]
  rules <- c(list(c(label = "Accuracy cut-off", threshold = m$default)),
             lapply(BUDGETS, function(b) c(label = sprintf("%s%% budget", formatC(100 * b, format = "g")),
                                           threshold = budget_threshold(m$train, y_train, b))))
  do.call(rbind, lapply(rules, function(r) {
    t <- as.numeric(r[["threshold"]])
    v <- rates_at(m$valid, y_valid, t)
    data.frame(model = name, rule = r[["label"]], threshold = t,
               spam_caught = v[["spam_caught"]], false_positive_rate = v[["false_positive_rate"]],
               legit_flagged = sum(m$valid[y_valid == 0] > t))
  }))
}))
write_csv(op, "outputs/operating_points.csv")

ranking <- data.frame(
  Model = names(models),
  `ROC AUC` = vapply(models, function(m) formatC(round(roc_auc(m$valid, y_valid), 4), format = "f", digits = 4), ""),
  `Average precision` = vapply(models, function(m) formatC(round(average_precision(m$valid, y_valid), 4), format = "f", digits = 4), ""),
  check.names = FALSE, row.names = NULL)

#### Figure: spam caught against legitimate mail flagged ####
curves <- do.call(rbind, lapply(names(models), function(name)
  data.frame(model = name, roc_points(models[[name]]$valid, y_valid))))
op_plot <- op
op_plot$label <- ifelse(op_plot$rule == "Accuracy cut-off", "accuracy cut-off", op_plot$rule)
fig <- ggplot(curves, aes(100 * false_positive_rate, 100 * spam_caught, colour = model)) +
  geom_step(direction = "vh", linewidth = 0.8) +
  geom_point(data = op_plot, size = 2.6) +
  geom_text(data = op_plot, aes(label = label), hjust = -0.12, vjust = 1.3, size = 3,
            show.legend = FALSE) +
  coord_cartesian(xlim = c(0, 10), ylim = c(0, 100)) +
  scale_colour_manual(values = c("Random forest" = "#2b6cb0", "Logistic regression" = "#c05621")) +
  labs(title = "How much spam is caught for each share of legitimate mail flagged",
       subtitle = paste0("Validation set (", format(n_legit, big.mark = ","),
                         " legitimate emails). Budget thresholds were chosen on training data only."),
       x = "Legitimate email flagged as spam (%)", y = "Spam caught (%)", colour = NULL) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank())
ggsave("docs/figures/operating_point.png", fig, width = 8, height = 5.2, dpi = 120, bg = "white")

report_add(
  "\n## 2. Operating point: spam caught under a false-positive budget\n\n",
  "Thresholds for a budget come from training data only: the random forest's out-of-bag votes and ",
  "5-fold cross-validated logistic-regression probabilities. They are then applied once to the ",
  sprintf("validation set (%s legitimate emails). The realized false-positive rate can land a ",
          format(n_legit, big.mark = ",")),
  "little above or below the budget, as it would on next month's mail.\n\n",
  paste(md_table(data.frame(
    Model = op$model, Rule = op$rule, Threshold = formatC(round(op$threshold, 3), format = "f", digits = 3),
    `Spam caught` = pct(op$spam_caught), `False-positive rate` = pct(op$false_positive_rate),
    `Legitimate emails flagged` = op$legit_flagged, check.names = FALSE)), collapse = "\n"), "\n\n",
  paste(md_table(ranking), collapse = "\n"), "\n\n",
  "![Operating point](figures/operating_point.png)\n"
)
