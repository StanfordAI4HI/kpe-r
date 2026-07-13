# Reward-model builders.

Each builder returns a list with a \`fit(X, y)\` method returning
\`self\` and a \`predict(X)\` method returning a numeric vector. The
cross-fit loop calls the builder once per fold to avoid state leakage
between folds.

## Usage

``` r
.reward_random_forest(
  seed = NULL,
  num_trees = 100L,
  rf_threads = getOption("kpe.rf_threads", 1L)
)
```
