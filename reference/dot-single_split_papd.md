# Per-shuffle PAPD worker: K-fold rotation of the centered IPW statistic.

Implements Eq. S18 of Li & Brunskill (2026). No reward model is fit;
centering is on the test-fold mean(Y).

## Usage

``` r
.single_split_papd(
  inputs,
  policy_builder,
  best_arm_builder,
  n_folds,
  seed,
  folds_override = NULL
)
```

## Arguments

- folds_override:

  Optional list of length n_folds with per-fold 1-based row indices,
  used by the Python-parity test.
