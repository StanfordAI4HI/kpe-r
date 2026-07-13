# PAPD baseline (Imai's Population Average Prescriptive Difference, centered).

3-fold rotation of the centered IPW statistic from Eq. S18 of Li &
Brunskill (2026). No reward model is fit; the `reward_model` argument is
accepted for API symmetry with
[`kpe`](https://stanfordai4hi.github.io/kpe-r/reference/kpe.md) and is
ignored. `n_folds` is also ignored – PAPD always uses 3 folds.

## Usage

``` r
papd(
  X,
  A,
  Y,
  propensity,
  n_shuffles = 100L,
  n_folds = 3L,
  contextual_policy = "policy_tree",
  best_arm = "ips",
  reward_model = "random_forest",
  policy_features = NULL,
  n_cores = 1L,
  seed = NULL,
  verbose = FALSE
)
```

## Arguments

- X:

  Numeric matrix or data frame of covariates, shape (n, d).

- A:

  Integer vector of observed treatments, values in \\\\0, \ldots,
  K-1\\\\. Factors are auto-coerced with a message.

- Y:

  Numeric vector of observed outcomes.

- propensity:

  Scalar, length-n vector, or (n, K) matrix. A scalar broadcasts; a
  vector is read as \\p(A_i \mid X_i)\\ for the observed action only.
  Required when `is_rct = TRUE` (the default); ignored when
  `is_rct = FALSE`, where the propensity is fit on the nuisance folds
  and `propensity` may be left `NULL`.

- n_shuffles:

  Number of Algorithm-1 repetitions (each with a different seed).
  Defaults to 100.

- n_folds:

  Number of folds \\K\\ the data is partitioned into per shuffle. Must
  be at least 2. Defaults to 6.

- contextual_policy:

  One of `"policy_tree"` or `"linear"`, or a list with `fit` and
  `predict` functions for a BYO contextual policy.

- best_arm:

  One of `"ips"` or `"simple"`, or a BYO `list(fit, predict)`.

- reward_model:

  One of `"random_forest"` or `"linear"`, or a BYO `list(fit, predict)`.

- policy_features:

  Optional integer vector of 1-based column indices passed to the
  contextual policy. Defaults to all columns.

- n_cores:

  Number of parallel workers for the shuffle loop. Defaults to 1
  (sequential).

- seed:

  Base random seed. Shuffle s uses `seed + s`.

- verbose:

  If `TRUE`, emits progress messages.

## Value

A `"kpe"` S3 object.
