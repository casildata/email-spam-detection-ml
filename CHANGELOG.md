# Changelog: from the original project to this release

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
