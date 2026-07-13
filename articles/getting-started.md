# Getting started

``` r

library(kpe)
```

This vignette shows the minimal sequence of calls needed to obtain a
personalization-effect estimate from
[`kpe()`](https://stanfordai4hi.github.io/kpe-r/reference/kpe.md).

> **kpe-r** is the R implementation; the Python version is
> [**kpe-py**](https://github.com/StanfordAI4HI/kpe-py). The package
> installs and loads as `kpe`
> ([`library(kpe)`](https://github.com/StanfordAI4HI/kpe-r)) — “kpe-r”
> is the project/repository name.

## Install

Installed from GitHub — not yet on CRAN (planned):

``` r

# install.packages("pak")
pak::pak("StanfordAI4HI/kpe-r")
# or: remotes::install_github("StanfordAI4HI/kpe-r")
```

## Learners and the packages they need

[`kpe()`](https://stanfordai4hi.github.io/kpe-r/reference/kpe.md) (and
[`train_eval()`](https://stanfordai4hi.github.io/kpe-r/reference/train_eval.md)
/ [`papd()`](https://stanfordai4hi.github.io/kpe-r/reference/papd.md))
plug in three learner “slots” — a **reward model**, a **contextual
policy**, and a **best-arm rule** — plus a **propensity model** when
`is_rct = FALSE`. Each slot takes a string naming a built-in backend.
The core `kpe` package `Imports` only `stats`, `future`, and
`future.apply`; the forest and penalized-regression backends live in
`Suggests`, so **you must install the R packages for the specific
learners your call uses.**

| slot | string value | backing R package (function) | required install |
|----|----|----|----|
| `reward_model` | `"random_forest"` | **`ranger`** ([`ranger::ranger`](http://imbs-hl.github.io/ranger/reference/ranger.md)) | `install.packages("ranger")` |
|  | `"linear"` | base R ([`stats::lm`](https://rdrr.io/r/stats/lm.html)) | — (always available) |
|  | `"ridge"`, `"lasso"` | **`glmnet`** | `install.packages("glmnet")` |
| `contextual_policy` | `"policy_tree"` (alias `"dr_econml_2"`) | **`policytree`** ([`policytree::policy_tree`](https://rdrr.io/pkg/policytree/man/policy_tree.html)); its doubly-robust nuisance scores additionally use **`glmnet`** + **`ranger`** | `install.packages(c("policytree","glmnet","ranger"))` |
|  | `"policy_forest"`, `"causal_forest"` | **`grf`** ([`grf::causal_forest`](https://rdrr.io/pkg/grf/man/causal_forest.html); binary treatment only) | `install.packages("grf")` |
|  | `"linear"` | base R (per-arm [`stats::lm`](https://rdrr.io/r/stats/lm.html)) | — |
| `best_arm` | `"ips"`/`"best_arm_erm"`, `"simple"`/`"simple_best_arm"` | built into `kpe` | — |
| `propensity_model` (only if `is_rct = FALSE`) | `"logistic"` | **`glmnet`** | `install.packages("glmnet")` |
|  | `"random_forest"` | **`ranger`** | `install.packages("ranger")` |

For example, the
[JobCorps](https://stanfordai4hi.github.io/kpe-r/articles/jobcorps.md)
vignette uses `reward_model = "random_forest"` and
`contextual_policy = "policy_tree"`, so it needs:

``` r

install.packages(c("ranger", "policytree", "glmnet"))
```

> **Which “random_forest”?** In this R package,
> `reward_model = "random_forest"` is the **`ranger`** implementation.
> That is a *different* random-forest library from the sibling Python
> package `kpe-py`, whose `"random_forest"` is scikit-learn’s
> `RandomForestRegressor`. Likewise R’s `"policy_tree"` (`policytree`)
> differs from Python’s `"policy_tree"` (econml `DRPolicyTree`). The two
> ports agree on `linear`/`lasso`-style learners but are **not** bitwise
> identical on the forest/tree learners.

## Example

``` r

set.seed(0)
n <- 400
X <- matrix(runif(n * 2, -1, 1), ncol = 2)
A <- rbinom(n, 1, 0.5)
Y <- ifelse(X[, 1] >= 0, A, 0.5 * (1 - A)) + rnorm(n, sd = 0.3)

fit <- kpe(X, A, Y, propensity = 0.5,
           n_shuffles        = 30,
           n_folds           = 6,
           contextual_policy = "linear",
           best_arm          = "simple",
           reward_model      = "linear",
           seed              = 0)
print(fit)
```

    ## K-Fold Personalization Estimator (kpe)
    ##   n_samples  = 400
    ##   n_shuffles = 30, n_folds = 6
    ##   psi        = 0.208 (SE 0.02505)
    ##   95% CI    = [0.1589, 0.2571]
    ##   p-value    = 8.033e-16 (one-sided)
    ##   policy stability = 0.9475

## Output fields

The returned object is an S3 list of class `"kpe"` with the following
elements:

| field | description |
|----|----|
| `psi` | Point estimate of the personalization effect on the outcome scale. |
| `std_error` | Standard error of `psi`. |
| `confidence_interval` | 95% Wald confidence interval, `c(lo, hi)`. |
| `p_value` | One-sided upper-tail t-test p-value. |
| `psi_per_shuffle` | Per-shuffle `psi_hat` values. |
| `sigma_per_shuffle` | Per-shuffle `sigma_hat` values. |
| `policy_stability` | Fraction of samples for which every shuffle agreed on the contextual-policy action. |
| `overall_stability` | Same fraction for the best-arm policy. |
| `predicted_policy_actions` | Length-`n` contextual-policy actions from the final shuffle. |
| `predicted_overall_actions` | Length-`n` best-arm actions from the final shuffle. |
| `method`, `n_samples`, `n_shuffles`, `n_folds` | Run metadata. |

`print`, `summary`, `confint`, and `coef` are defined for the `"kpe"`
class:

``` r

confint(fit)
```

    ##          2.5%     97.5%
    ## psi 0.1588785 0.2570822

``` r

coef(fit)
```

    ##       psi 
    ## 0.2079803

## Input specification

| argument | type | description |
|----|----|----|
| `X` | numeric matrix or data frame | `n × d` covariate matrix. |
| `A` | integer vector | Length-`n` observed action in `{0, ..., K-1}`. Factors are coerced. |
| `Y` | numeric vector | Length-`n` observed outcome. |
| `propensity` | scalar, vector, or matrix | `p(A \| X)` for the observed action. Scalars and length-`n` vectors are broadcast. |
| `policy_features` | integer vector, optional | 1-based column indices of `X` passed to the contextual-policy learner. |

## Further reading

- [Methods](https://stanfordai4hi.github.io/kpe-r/articles/methods.md) —
  the algorithm and variance decomposition.
- [Baselines](https://stanfordai4hi.github.io/kpe-r/articles/baselines.md)
  — the
  [`train_eval()`](https://stanfordai4hi.github.io/kpe-r/reference/train_eval.md)
  and
  [`papd()`](https://stanfordai4hi.github.io/kpe-r/reference/papd.md)
  estimators.
- Dataset vignettes:
  [JobCorps](https://stanfordai4hi.github.io/kpe-r/articles/jobcorps.md),
  [Joke](https://stanfordai4hi.github.io/kpe-r/articles/joke.md).
- [User-supplied
  learners](https://stanfordai4hi.github.io/kpe-r/articles/byo.md) —
  protocols for plugging custom `fit` / `predict` objects into each
  slot.
