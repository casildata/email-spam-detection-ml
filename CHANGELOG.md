# Changelog: from the original project to this release

## Refactor for publication (2026)
- Consolidated the project into one script (`scripts/spam_classifier.R`) under version control.
- Removed kNN data leakage: the final model now fits on training rows only. Impact measured in `analysis/knn_leakage_check.py`.
- Ensemble votes are now summed by column name, so only model votes count toward the majority.
- Plots are saved as PNGs (tree and feature importance to `docs/figures/`, cut-off curves to `outputs/`) instead of an untracked `Rplots.pdf`.
- Replaced absolute paths with relative paths; bundled UCI Spambase (CC BY 4.0) so the project runs out of the box.

## Not included
Third-party materials from the original program and the co-authored slide deck.
