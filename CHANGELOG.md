# Changelog: from the original project to this release

## 2026-10-22: operating point, robustness, tests and CI
- `run_all.R` runs three numbered scripts and writes every reported number to `docs/results.md`.
- New `scripts/02_operating_point.R`: spam caught at 1% and 0.1% false-positive budgets, with thresholds chosen on training data only (random-forest out-of-bag votes, cross-validated logistic-regression scores); ROC AUC and average precision; the new README hero figure.
- New `scripts/03_robustness.R`: random forest over 10 splits on all emails, with duplicates removed, and without nine recipient-specific words; duplicate counts across the main split.
- k for k-NN is now chosen by 5-fold cross-validation on the training rows (k = 5) instead of on the validation set; the k-NN leak is measured on the same split. The random forest, logistic regression, neural network and tree are unchanged.
- `testthat` suite (30 expectations), `renv.lock`, and CI: tests, pipeline, a check that `docs/results.md` is reproduced exactly, tests on R 4.5, gitleaks.
- Framework mapping (ATT&CK T1566 as context, CIS 9.7, CSF DE.CM-09) in the README.

## 2026-10-22: review fixes
- Results now report spam caught and the false-positive rate next to accuracy, with two baselines (always "not spam", and the best single rule); the script writes them to `outputs/metrics.csv`.
- README: Limitations and Roadmap sections; the security rationale now matches what is reported.
- Removed a stale correlation heatmap from `docs/figures/` that no script produced.
- The R and Python package checks no longer install anything; they stop with the install command.
- Dropped the `forecast` and `reshape` dependencies.

## Refactor for publication (2026)
- Consolidated the project into one script (`scripts/spam_classifier.R`) under version control.
- Removed kNN data leakage: the final model now fits on training rows only. Impact measured in `analysis/knn_leakage_check.py`.
- Ensemble votes are now summed by column name, so only model votes count toward the majority.
- Plots are saved as PNGs (tree and feature importance to `docs/figures/`, cut-off curves to `outputs/`) instead of an untracked `Rplots.pdf`.
- Replaced absolute paths with relative paths; bundled UCI Spambase (CC BY 4.0) so the project runs out of the box.

## Not included
Third-party materials from the original program and the co-authored slide deck.
