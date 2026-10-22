# Reproduce every table and figure from the repository root:
#   Rscript run_all.R
# Packages: listed in r-packages.txt; the run stops with install instructions if any are missing.
source("R/functions.R")
source("R/evaluation.R")
source("R/report.R")

dir.create("outputs", showWarnings = FALSE)
dir.create("docs/figures", showWarnings = FALSE, recursive = TRUE)

for (s in c("scripts/01_model_comparison.R", "scripts/02_operating_point.R",
            "scripts/03_robustness.R")) {
  message("==> ", s)
  source(s, echo = FALSE)
}
report_write("docs/results.md")
message("Results written to docs/results.md")
