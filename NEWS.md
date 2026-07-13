# kpe 0.1.0

* Initial release. Point estimate, confidence interval, and one-sided p-value
  for the personalization effect via the two-fold K-Fold Personalization Estimator of
  Li and Brunskill (2026).
* Three estimators — `kpe()`, `train_eval()`, and `papd()` — sharing one
  argument signature and returning a `"kpe"` S3 object with `print()`,
  `summary()`, `confint()`, and `coef()` methods.
* Pluggable reward, contextual-policy, and best-arm learners via built-in
  strings (backed by `ranger`, `policytree`, `grf`, `glmnet` in `Suggests`) or
  user-supplied `fit`/`predict` objects.
* The estimate is reproducible regardless of `n_cores`: the per-shuffle fold
  split and the forest seeds are pinned to be independent of the parallel
  backend.
