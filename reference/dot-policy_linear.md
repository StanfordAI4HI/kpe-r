# Contextual-policy builders.

Each builder returns a list with \`fit(X, A, Y, n_actions)\` returning
\`self\` and \`predict(X)\` returning an integer vector of actions.

## Usage

``` r
.policy_linear(seed = NULL, alpha = 0)
```
