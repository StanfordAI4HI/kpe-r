# String -\> builder resolvers for reward, policy, and best-arm learners.

BYO path: users may pass a list with \`fit\` and \`predict\` functions.
The resolver wraps it so the same instance is returned fresh per fold.

## Usage

``` r
.resolve_reward(spec, seed = NULL)
```
