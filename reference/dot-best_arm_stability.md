# Share of shuffles whose best-arm choice equals the modal best arm.

Matches the paper's Table S1 \*best-arm\* stability ("percentage of the
occurrence of the most frequently output best intervention across splits
and folds"). For (S, n) input each row is reduced to its modal action
(defensive against non-constant rows); the return value is the largest
cross-shuffle action share. Unanimously chosen best arm returns 1; an
even split across K arms returns 1/K. 1-D input is treated as a single
vector of best-arms.

## Usage

``` r
.best_arm_stability(action_matrix)
```

## Arguments

- action_matrix:

  integer matrix (S, n) or integer vector.
