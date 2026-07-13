# Propensity-model builders: estimate p(a \| x) for each action.

Used only when \`kpe(..., is_rct = FALSE)\`. For RCT data the known
propensity is passed in and these are never fit. Each builder returns a
list with \`fit(X, A, n_actions)\` returning \`self\` and
\`predict_proba(X)\` returning an (n, n_actions) matrix with columns
aligned to actions 0..n_actions-1; absent actions get a small floor
probability and rows are renormalized.

## Usage

``` r
.align_proba(raw, present_actions, n_actions, floor = 1e-06)
```
