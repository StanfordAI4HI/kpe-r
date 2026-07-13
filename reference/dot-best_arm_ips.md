# Best-arm builders: pick one action for everyone.

Each builder returns a list with \`fit(A, Y, propensities, n_actions)\`
returning \`self\` and \`predict()\` returning an integer 0..K-1.

## Usage

``` r
.best_arm_ips(seed = NULL)
```
