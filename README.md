# Email Spam Detection: Comparing Five ML Classifiers + Ensemble

**Classifying email as spam or legitimate using word, character and capitalization frequencies. This is the content-filtering layer behind phishing and spam defenses.**

![R](https://img.shields.io/badge/R-4.5%2B-276DC3?logo=r&logoColor=white)
![Models](https://img.shields.io/badge/models-Logit%20%7C%20kNN%20%7C%20Tree%20%7C%20ANN%20%7C%20Random%20Forest%20%7C%20Ensemble-informational)
![Domain](https://img.shields.io/badge/domain-Email%20Security-critical)
![License](https://img.shields.io/badge/license-MIT-green)

> **Origin:** a two-person graduate project in **Machine Learning** at Texas Tech University (2022), refactored for publication.

---

## TL;DR

- **Data:** [UCI Spambase](https://archive.ics.uci.edu/dataset/94/spambase), 4,601 emails (39.4% spam) × 57 numeric features (frequencies of words like `free`, `remove`, `credit`; characters `!` `$`; runs of CAPITALS).
- **Best model:** Random forest, **94.95% validation accuracy**, against 79.46% for the best single rule and 61.74% for always answering "not spam". The majority-vote ensemble reaches 94.08%.
- **The catch:** the forest still flags **3.35%** of legitimate email as spam, about 1 in 30. That's the number a mail-security team would push on, and it's next on the roadmap.
- **Audit finding:** while preparing this repo I found that the kNN model had been fit on data that included the validation rows. A Python re-check shows this inflated kNN accuracy from **~89.8% to ~92.8%**. The code is fixed and the check is included ([`analysis/knn_leakage_check.py`](analysis/knn_leakage_check.py)).

---

## Approach

### Pipeline

```mermaid
flowchart LR
    A["Spambase CSV<br/>4,601 × 58"] --> B["Rename special-char columns<br/>correlation screen"]
    B --> C["Drop word_freq_415<br/>(r = 0.996 with word_freq_857)"]
    C --> D["Stratified 60/40 split"]
    D --> E1["Raw features"] --> M1["Logistic regression"] & M3["Classification tree"] & M5["Random forest"]
    D --> E2["Standardized<br/>(fit on train)"] --> M2["k-NN, k ∈ {1,3,…,19}"]
    D --> E3["Min-max scaled<br/>(fit on train)"] --> M4["Neural net 1×2"]
    M1 & M2 & M4 & M5 --> F["Ensemble<br/>majority vote · avg probability"]
    M1 & M2 & M3 & M4 & M5 & F --> G["Confusion matrices<br/>spam = positive class"]
```

### Why this matters for security

Spam filtering is the original ML-in-security problem, and the same pipeline shape carries over to phishing-email triage, malicious-attachment scoring, and alert classification. In a mail-security context the costs are asymmetric: a false positive (a real email quarantined) costs differently from a false negative (phish delivered). That is why the results below report the false-positive rate and the share of spam caught next to accuracy. The probability cut-offs are still chosen to maximize accuracy, which weighs both errors equally; choosing them for a false-positive budget is the first item on the [roadmap](#roadmap).

## Results

Validation results on a 40% stratified holdout (1,840 emails), from `Rscript scripts/spam_classifier.R` with the leakage and ensemble fixes applied. The run is seeded (`set.seed(1)`), so re-running it reproduces these numbers; the script also writes them to `outputs/metrics.csv`. **Spam caught** is sensitivity; **false-positive rate** is the share of legitimate email flagged as spam (1 − specificity).

| Model | Accuracy | Spam caught | False-positive rate | Notes |
|---|---|---|---|---|
| **Random forest** | **94.95%** | 92.19% | **3.35%** | Best overall |
| Ensemble: majority vote | 94.08% | 91.76% | 4.49% | Logit + kNN + ANN + RF; a 2–2 tie goes to the average probability |
| Ensemble: average probability | 93.91% | 91.34% | 4.49% | Logit + kNN + ANN + RF |
| Logistic regression | 92.66% | 92.76% | 7.39% | Probability cut-off tuned on training data |
| Neural network (1 hidden layer, 2 nodes) | 92.55% | 90.34% | 6.07% | Inputs min-max scaled on training data |
| k-NN (k = 7) | 90.54% | 84.80% | 5.90% | Fit on training rows only; the original leaky fit scored 92.29% (see below) |
| Classification tree | 88.37% | 81.53% | 7.39% | Most interpretable |
| *Baseline: one rule* | *79.46%* | *75.85%* | *18.31%* | *Flag if `!` makes up at least 0.08% of characters (the best single split)* |
| *Baseline: always "not spam"* | *61.74%* | *0%* | *0%* | *The share of legitimate email* |

The models add about 15 points over the best one-line rule. But even the best model flags 3.35% of legitimate email, roughly 1 in 30, which is too many for a production mail filter. Accuracy alone hides that.

| Random forest: top 15 features | Classification tree |
|---|---|
| ![Random forest feature importance](docs/figures/rf_feature_importance.png) | ![Classification tree](docs/figures/classification_tree.png) |

Both models lean on the same signals: `!` and `$` frequency, "remove", and runs of capital letters.

## Limitations & lessons learned

**Why the kNN number changed.** The original call was `knn(train = <full standardized dataset>, test = <validation rows>)`, so each validation email could find *itself* among its neighbours. Re-implemented in scikit-learn over 20 random 60/40 splits: leaky setup **92.8% ± 0.5%**, correct setup **89.8% ± 0.5%**.

**Limitations of the data and the evaluation**

- **One mailbox from 1999.** Spambase was collected from a single HP Labs mailbox. Words that identify that recipient, such as `hp`, `george` and `hpl`, appear among the random forest's top 15 features, so part of the score wouldn't carry over to someone else's mail. Modern phishing also looks very different from 1990s spam.
- **Duplicate emails.** Spambase contains exact duplicate rows, and some land on both sides of the random split, which flatters every model slightly.
- **Pre-computed features only.** The data is 57 word and character frequencies, not raw text, so this model can't score a real email without re-deriving those features.
- **One split, accuracy-tuned cut-offs.** Results come from a single seeded 60/40 split. k for k-NN is chosen on the validation set (mildly optimistic), and cut-offs maximize accuracy rather than respecting a false-positive budget.

## Getting started

### Requirements

- R 4.5 or later (tested on 4.6.1) with the packages below (`neuralnet` depends on `Deriv`, which needs R 4.5).
- Optional, for the leakage check: Python 3.10 or later (tested on 3.14) with NumPy, pandas and scikit-learn (`analysis/requirements.txt`).
- Data ships with the repo in `data/raw/spambase.csv`.

### Install

```r
install.packages(c("tidyverse", "caret", "FNN", "rpart", "rpart.plot",
                   "randomForest", "neuralnet"))
```

```bash
pip install -r analysis/requirements.txt    # optional leakage check
```

The scripts never install anything. If a package is missing, they stop and print the command to run. The R list lives in [`r-packages.txt`](r-packages.txt).

### Run

From the repository root:

```bash
Rscript scripts/spam_classifier.R
python analysis/knn_leakage_check.py data/raw/spambase.csv        # optional leakage check
```

### Output

About 30 seconds. The tree and feature-importance figures are written to `docs/figures/` (tracked, shown above). The metrics table (`metrics.csv`), the correlation heatmap, the cut-off tuning curves for logistic regression and the neural network, and the validation predictions are written to `outputs/` (git-ignored).

## Repository structure

```
email-spam-detection-ml/
├── r-packages.txt              # R packages the scripts need
├── R/
│   ├── check_packages.R        # stops with an install command if a package is missing
│   └── functions.R             # cut-off tuning, confusion-matrix and metrics helpers, libraries
├── scripts/spam_classifier.R   # end-to-end: EDA → 5 models → ensemble
├── analysis/
│   ├── knn_leakage_check.py    # reproduces the kNN leakage finding (scikit-learn)
│   ├── check_requirements.py   # stops with the pip command if a package is missing
│   └── requirements.txt        # Python packages for the leakage check
├── data/
│   ├── README.md               # source, license, citation
│   └── raw/spambase.csv        # UCI Spambase (CC BY 4.0)
├── docs/figures/               # README figures (tree, feature importance)
├── outputs/                    # generated, .gitignored
├── CHANGELOG.md
└── LICENSE
```

## Skills demonstrated

`Supervised classification` · `Model comparison` · `Ensemble methods` · `Feature scaling without leakage` · `Hyperparameter / threshold tuning` · `Code audit & reproducibility` · `R` · `Python / scikit-learn`

## Roadmap

- Evaluate against a false-positive budget: spam caught at a 1% and 0.1% false-positive rate, ROC and precision-recall curves, and a cut-off chosen on a validation fold and reported on a held-out test set.
- Remove duplicate emails before splitting, and report the mean and spread over several random splits.
- A "generic" model without the recipient-specific words (`hp`, `george`, …), to estimate how the filter would do on another mailbox.
- Choose k for k-NN by cross-validation on the training set.
- Tests, a pinned R environment (`renv.lock`) and CI that re-runs the script and checks the reported numbers.
- Rebuild the features from raw email text and test on a modern phishing corpus.

## Data & citations

Hopkins, M., Reeber, E., Forman, G., & Suermondt, J. (1999). *Spambase* [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C53G6X. Licensed CC BY 4.0.

## Credits & Collaboration

The original 2022 analysis was a two-person graduate project in Machine Learning at Texas Tech University.

* **Javier Casildo**
* **Team Member:** one collaborator (name omitted for privacy)

*Note: Team member profiles will be linked with their permission.*

## License

Code: MIT. See [LICENSE](LICENSE). Dataset: CC BY 4.0 (UCI).
