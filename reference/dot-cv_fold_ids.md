# Deterministic CV fold ids (no global-RNG side effects). Row i is assigned to fold (i mod cv), giving cv roughly-equal contiguous-by-stride folds.

Deterministic CV fold ids (no global-RNG side effects). Row i is
assigned to fold (i mod cv), giving cv roughly-equal
contiguous-by-stride folds.

## Usage

``` r
.cv_fold_ids(n, cv)
```
