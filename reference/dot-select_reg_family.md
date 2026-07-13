# Choose "linear" (CV-Lasso) vs "forest" (random forest) by cross-validated MSE on the joint regression task Y ~ \[X, onehot(A)\]. Returns "linear" or "forest". Mirrors econml's ListSelector picking the higher-scoring of the two "auto" candidates.

Choose "linear" (CV-Lasso) vs "forest" (random forest) by
cross-validated MSE on the joint regression task Y ~ \[X, onehot(A)\].
Returns "linear" or "forest". Mirrors econml's ListSelector picking the
higher-scoring of the two "auto" candidates.

## Usage

``` r
.select_reg_family(
  X,
  A,
  Y,
  n_actions,
  cv = 2L,
  seed = NULL,
  num_trees = 100L,
  rf_threads = 1L
)
```
