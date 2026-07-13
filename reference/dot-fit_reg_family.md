# Fit one regression family. \`family\` is "linear" (cv.glmnet LASSO, lambda chosen by internal CV) or "forest" (ranger random forest). Feature matrix already includes the treatment one-hot columns.

Fit one regression family. \`family\` is "linear" (cv.glmnet LASSO,
lambda chosen by internal CV) or "forest" (ranger random forest).
Feature matrix already includes the treatment one-hot columns.

## Usage

``` r
.fit_reg_family(
  family,
  feat,
  y,
  seed = NULL,
  num_trees = 100L,
  rf_threads = 1L
)
```
