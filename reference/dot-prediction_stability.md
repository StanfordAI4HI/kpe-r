# Fraction of samples for which all shuffles agree on the predicted action.

Matches the paper's Table S1 \*policy\* stability: \\1 - (1/\|X\|)
\sum_x I(\exists s, s' : \pi_s(x) \neq \pi\_{s'}(x))\\. Use this on
per-sample policy-action matrices, not on the best-arm matrix (each
best-arm row is broadcast-constant so this would collapse to 0 or 1; use
\[.best_arm_stability\] instead).

## Usage

``` r
.prediction_stability(action_matrix)
```

## Arguments

- action_matrix:

  (S, n) integer matrix; row s holds one shuffle's per-sample predicted
  action.
