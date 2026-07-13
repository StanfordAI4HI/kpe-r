# AIPW influence function for the personalization effect.

Equation S17 of Li & Brunskill (2026): per-sample psi combining a
plug-in reward-model difference with an IPW correction that centers the
estimator on the held-out fold. Mirrors
\`kpe-py/src/kpe/core/influence.py::aipw_influence\`.

## Usage

``` r
.aipw_influence(
  X,
  A,
  Y,
  X_policy,
  propensity_observed,
  reward_model,
  contextual_policy,
  best_arm
)
```

## Value

list with \`psi\` (numeric length n_test), \`policy_action\` (integer),
\`overall_action\` (integer).
