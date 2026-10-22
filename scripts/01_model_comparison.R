#### Email Spam Classification -- five models + ensemble ####
# Run from the repository root through run_all.R.
# Data: UCI Spambase (4,601 emails, 57 numeric features, label `spam`), see data/README.md

set.seed(1)

#### Load & tidy ####
data <- read_csv("data/raw/spambase.csv", show_col_types = FALSE) %>%
  dplyr::rename(char_freq_semi   = `char_freq_;`,
         char_freq_par    = `char_freq_(`,
         char_freq_brack  = `char_freq_[`,
         char_freq_excl   = `char_freq_!`,
         char_freq_dollar = `char_freq_$`) %>%
  as.data.frame()
n_emails <- nrow(data)
spam_share <- mean(data$spam)

#### Correlation screening ####
cor.mat <- round(cor(data), 2)
melted.cor.mat <- setNames(as.data.frame(as.table(cor.mat)), c("X1", "X2", "value"))
heatmap <- ggplot(melted.cor.mat, aes(x = X1, y = X2, fill = value)) +
  geom_tile() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1))
ggsave("outputs/correlation_heatmap.png", heatmap, width = 14, height = 12, dpi = 120)

r_415_857 <- cor(data$word_freq_415, data$word_freq_857)  # the only pair above 0.9
data <- data[, setdiff(colnames(data), "word_freq_415")]

#### Partition 60 / 40 (stratified) ####
dep_var <- which(colnames(data) == "spam")
train_index <- createDataPartition(data$spam, p = 0.6, list = FALSE)
train_df <- data[train_index, ]
valid_df <- data[-train_index, ]

# Scalers are fit on the training rows only, then applied to validation rows
pp_norm  <- preProcess(train_df[, -dep_var], method = "range")
pp_stand <- preProcess(train_df[, -dep_var], method = c("center", "scale"))
train_norm  <- train_df; train_norm[, -dep_var]  <- predict(pp_norm,  train_df[, -dep_var])
valid_norm  <- valid_df; valid_norm[, -dep_var]  <- predict(pp_norm,  valid_df[, -dep_var])
train_stand <- train_df; train_stand[, -dep_var] <- predict(pp_stand, train_df[, -dep_var])
valid_stand <- valid_df; valid_stand[, -dep_var] <- predict(pp_stand, valid_df[, -dep_var])

#### (1) Logistic regression ####
logit <- suppressWarnings(glm(spam ~ ., data = train_df, family = "binomial"))
cut_off_logit <- max_accuracy(train_df$spam, predict(logit, type = "response", newdata = train_df),
                              plot_file = "outputs/cutoff_logit.png")
logit_valid_prob <- predict(logit, type = "response", newdata = valid_df)
logit_prediction <- ifelse(logit_valid_prob > cut_off_logit, 1, 0)

#### (2) k-nearest neighbours ####
# k is chosen by 5-fold cross-validation on the training rows, with the scaler refit inside
# each fold, so the validation set plays no part in the choice. The random-number state is
# restored afterwards, so the models below draw exactly the numbers they drew before.
rng_state <- .Random.seed
k_grid <- seq(1, 19, 2)
folds <- createFolds(factor(train_df$spam), k = 5)
cv_accuracy <- vapply(k_grid, function(k) mean(vapply(folds, function(f) {
  pp <- preProcess(train_df[-f, -dep_var], method = c("center", "scale"))
  pred <- knn(train = predict(pp, train_df[-f, -dep_var]), test = predict(pp, train_df[f, -dep_var]),
              cl = train_df$spam[-f], k = k)
  mean(as.character(pred) == as.character(train_df$spam[f]))
}, numeric(1))), numeric(1))
assign(".Random.seed", rng_state, envir = globalenv())
k_val <- k_grid[which.max(cv_accuracy)]

knn_fit <- knn(train = train_stand[, -dep_var], test = valid_stand[, -dep_var],
               cl = train_stand$spam, k = k_val, prob = TRUE)

# The 2022 version standardized the FULL dataset and passed all of it as the training set,
# so each validation email could find itself as a neighbour. Measured on the same split:
pp_all <- preProcess(data[, -dep_var], method = c("center", "scale"))
knn_leaky <- knn(train = predict(pp_all, data[, -dep_var]), test = predict(pp_all, valid_df[, -dep_var]),
                 cl = data$spam, k = k_val)

#### (3) Classification tree ####
tree <- rpart(spam ~ ., data = train_df, method = "class")
save_png("docs/figures/classification_tree.png", function() prp(tree), width = 1400, height = 900)
tree_prediction <- predict(tree, newdata = valid_df, type = "class")

#### (4) Neural network (1 hidden layer, 2 nodes) ####
nn <- neuralnet(spam ~ ., data = train_norm, linear.output = FALSE, hidden = 2)
cut_off_ann <- max_accuracy(train_norm$spam, compute(nn, train_norm)$net.result[, 1],
                            plot_file = "outputs/cutoff_ann.png")
ann_prob <- compute(nn, valid_norm)$net.result[, 1]
ann_prediction <- ifelse(ann_prob > cut_off_ann, 1, 0)

#### (5) Random forest ####
forest <- randomForest(factor(spam) ~ ., data = train_df)
forest_prediction  <- predict(forest, newdata = valid_df)
forest_probability <- predict(forest, newdata = valid_df, type = "prob")[, "1"]
save_png("docs/figures/rf_feature_importance.png",
         function() varImpPlot(forest, n.var = 15, main = "Random forest -- top 15 features"))

#### Ensemble (logit, kNN, ANN, RF) ####
knn_prob_spam <- ifelse(knn_fit == "1", attr(knn_fit, "prob"), 1 - attr(knn_fit, "prob"))
results <- data.frame(
  actual      = valid_df$spam,
  logit_prob  = logit_valid_prob,
  knn_prob    = knn_prob_spam,
  ann_prob    = ann_prob,
  forest_prob = forest_probability,
  logit_pred  = logit_prediction,
  knn_pred    = as.numeric(as.character(knn_fit)),
  ann_pred    = ann_prediction,
  forest_pred = as.numeric(as.character(forest_prediction))
)
results$avg   <- rowMeans(results[, c("logit_prob", "knn_prob", "ann_prob", "forest_prob")])
# Fixed: the original summed columns 6:10, which silently included the `avg` probability in the vote count
results$votes <- rowSums(results[, c("logit_pred", "knn_pred", "ann_pred", "forest_pred")])
results$majority <- ifelse(results$votes == 2, ifelse(results$avg > 0.5, 1, 0),  # 2-2 tie -> average probability
                           ifelse(results$votes > 2, 1, 0))
write_csv(results, "outputs/validation_predictions.csv")

#### Baselines and per-model metrics ####
# Baselines give the models context: always answering "not spam", and the single best
# rule (a one-split tree). xval = 0 keeps rpart from drawing random numbers.
stump <- rpart(spam ~ ., data = train_df, method = "class",
               control = rpart.control(maxdepth = 1, xval = 0))
stump_prediction <- as.numeric(as.character(predict(stump, newdata = valid_df, type = "class")))
stump_rule <- sprintf("%s >= %.2f", rownames(stump$splits)[1], stump$splits[1, "index"])

metrics <- rbind(
  "Random forest"                 = spam_metrics(forest_prediction, valid_df$spam),
  "Ensemble: majority vote"       = spam_metrics(results$majority, results$actual),
  "Ensemble: average probability" = spam_metrics(ifelse(results$avg > 0.5, 1, 0), results$actual),
  "Logistic regression"           = spam_metrics(logit_prediction, valid_df$spam),
  "Neural network"                = spam_metrics(ann_prediction, valid_df$spam),
  "k-NN"                          = spam_metrics(knn_fit, valid_df$spam),
  "Classification tree"           = spam_metrics(tree_prediction, valid_df$spam),
  "Baseline: one rule"            = spam_metrics(stump_prediction, valid_df$spam),
  "Baseline: always not spam"     = spam_metrics(rep(0, nrow(valid_df)), valid_df$spam)
)
metrics <- data.frame(model = rownames(metrics), round(100 * metrics, 2), row.names = NULL)
write_csv(metrics, "outputs/metrics.csv")

report_add(
  "## 1. Model comparison\n\n",
  sprintf("%s emails, %s%% spam. `word_freq_415` is dropped (r = %.3f with `word_freq_857`). ",
          format(n_emails, big.mark = ","), pct(spam_share, 1), round(r_415_857, 3)),
  sprintf("Stratified 60/40 split: %s training and %s validation emails (%s legitimate).\n\n",
          format(nrow(train_df), big.mark = ","), format(nrow(valid_df), big.mark = ","),
          format(sum(valid_df$spam == 0), big.mark = ",")),
  "**Spam caught** is sensitivity; **false-positive rate** is the share of legitimate email ",
  "flagged as spam (1 - specificity). Cut-offs: 0.5 for the forest and tree; tuned for accuracy ",
  "on training predictions for logistic regression and the neural network.\n\n",
  paste(md_table(data.frame(
    Model = sub("^k-NN$", sprintf("k-NN (k = %d)", k_val), metrics$model),
    Accuracy = pct(metrics$accuracy / 100), `Spam caught` = pct(metrics$sensitivity / 100),
    `False-positive rate` = pct(metrics$false_positive_rate / 100), check.names = FALSE)),
    collapse = "\n"), "\n\n",
  sprintf("One-rule baseline: flag the email if `%s` (the best single split).\n\n", stump_rule),
  sprintf("**k for k-NN** was chosen by 5-fold cross-validation on the training rows: k = %d ", k_val),
  sprintf("(CV accuracy %s%%).\n\n", pct(max(cv_accuracy))),
  sprintf("**k-NN leakage (the 2022 bug), same split and k:** trained on all rows %s%%, ",
          pct(mean(as.character(knn_leaky) == as.character(valid_df$spam)))),
  sprintf("trained on training rows only %s%%.\n\n",
          pct(mean(as.character(knn_fit) == as.character(valid_df$spam)))),
  "![Feature importance](figures/rf_feature_importance.png)\n"
)
