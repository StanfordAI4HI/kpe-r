# Cross-fitted, X-dependent per-arm outcome regression mu_hat_a(X).

Fits a single joint regression mu_hat(X, onehot(A)) -\> Y with
\`cv\`-fold cross-fitting and returns the out-of-fold prediction matrix
mu_oof of shape (n, n_actions): mu_oof\[i, a + 1\] = mu_hat_a(X_i)
evaluated by setting the treatment one-hot to arm a. The regression
family (CV-Lasso vs random forest) is chosen once on the full fold by
cross-validated MSE, replicating econml's model_regression = "auto"
(ListSelector(\["linear", "forest"\])).

## Usage

``` r
.dr_crossfit_mu(
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
