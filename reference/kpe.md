# K-Fold Personalization Estimator

Point estimate, confidence interval, and one-sided p-value for the
personalization effect – the expected outcome difference between the
best personalized policy and the best single treatment applied to
everyone. Implements Algorithm 1 of Li & Brunskill (2026), layered on
the kpe2 shared-nuisance cross-fit pass in
[`.single_split_kpe`](https://stanfordai4hi.github.io/kpe-r/reference/dot-single_split_kpe.md),
which fits every nuisance (reward model, contextual policy, best single
arm, and – when `is_rct = FALSE` – the propensity) on a shared set of
`n_nuisance_folds` folds and evaluates the AIPW influence on the
held-out block. The default is leave-one-fold-out: with `n_folds = 6`,
every nuisance is fit on 5/6 of the data and evaluated on the held-out
1/6, rotated six times.

## Usage

``` r
kpe(
  X,
  A,
  Y,
  propensity = NULL,
  n_shuffles = 100L,
  n_folds = 6L,
  n_nuisance_folds = NULL,
  is_rct = TRUE,
  contextual_policy = "policy_tree",
  best_arm = "ips",
  reward_model = "random_forest",
  propensity_model = "logistic",
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

- n_nuisance_folds:

  Number of folds \\m\\ used to fit all nuisances. Defaults to
  `n_folds - 1`. The evaluation block size is \\b = n\\folds - m\\ and
  must divide `n_folds` (non-overlapping blocks), so each sample is
  evaluated exactly once per shuffle. The default gives
  leave-one-fold-out.

- is_rct:

  Logical. If `TRUE` (default), `propensity` is the known design
  propensity and nothing is fit for it. If `FALSE`, an estimated \\\hat
  p(a \mid x)\\ is fit on the nuisance folds (via `propensity_model`)
  and used in both the AIPW evaluation and the best-arm IPS.

- contextual_policy:

  One of `"policy_tree"` or `"linear"`, or a list with `fit` and
  `predict` functions for a BYO contextual policy.

- best_arm:

  One of `"ips"` or `"simple"`, or a BYO `list(fit, predict)`.

- reward_model:

  One of `"random_forest"` or `"linear"`, or a BYO `list(fit, predict)`.

- propensity_model:

  One of `"logistic"` or `"random_forest"`, or a BYO
  `list(fit, predict)`. Used only when `is_rct = FALSE`.

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

An object of class `"kpe"` (an S3 list). See
[`print.kpe`](https://stanfordai4hi.github.io/kpe-r/reference/print.kpe.md)
and
[`summary.kpe`](https://stanfordai4hi.github.io/kpe-r/reference/summary.kpe.md).

## References

Li Z., Brunskill E. (2026) \*A Statistical Test for the Benefits of
Personalizing Interventions\*.

## Examples

``` r
set.seed(0)
n <- 200
X <- matrix(runif(n * 3, -1, 1), ncol = 3)
A <- rbinom(n, 1, 0.5)
Y <- ifelse(X[, 1] >= 0, A, 0.5 * (1 - A)) + rnorm(n, sd = 0.3)
fit <- kpe(X, A, Y, propensity = 0.5,
           n_shuffles = 4, n_folds = 6,
           contextual_policy = "linear",
           best_arm = "simple",
           reward_model = "linear",
           seed = 0)
print(fit)
#> K-Fold Personalization Estimator (kpe)
#>   n_samples  = 200
#>   n_shuffles = 4, n_folds = 6
#>   psi        = 0.2073 (SE 0.03445)
#>   95% CI    = [0.1397, 0.2748]
#>   p-value    = 4.199e-09 (one-sided)
#>   policy stability = 0.97
```
