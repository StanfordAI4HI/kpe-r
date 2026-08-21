# Joke

The Jester joke-ratings dataset is encoded as a contextual bandit with
10 actions (joke IDs), 100-dimensional random-projection contexts, and a
rating outcome normalized to `[0, 5.0]`.

The code assumes that you have created a KPE_DATA_DIR env variable which
points to the directory where you are storing `RCT_joke_data.csv` (n =
48 445).

The RCT_joke_data.csv is a preprocessed RCT form of the Jester dataset
\[<https://goldberg.berkeley.edu/jester-data/>\]. See details here:
<https://datadryad.org/dataset/doi:10.5061/dryad.bg79cnpp7>

## Prerequisites

This vignette assumes `kpe` is installed with the learner backends its
call uses. It calls `reward_model = "lasso"`, which requires the
**`glmnet`** package (the `"linear"` contextual policy needs no extra
package). See
[`vignette("getting-started", package = "kpe")`](https://stanfordai4hi.github.io/kpe-r/articles/getting-started.md)
for installation and the full learner/backend table.

It also requires `RCT_joke_data.csv` and the `KPE_DATA_DIR` environment
variable pointing to the directory that contains it (see above); the
code chunks below are skipped when `KPE_DATA_DIR` is unset.

This dataset can be accessed by cloning the repository and looking in
the “vignettes” directory. git clone
<https://github.com/StanfordAI4HI/kpe-r.git>

## Setup

``` r

library(kpe)
options(future.globals.maxSize = 1000 * 1024^2)

# Processed Jester arrays (columns X0..X99, A, Y), exported once from
# RCT_joke_data.pkl to a CSV that both the R and Python vignettes read.
df <- read.csv(file.path(Sys.getenv("KPE_DATA_DIR"), "RCT_joke_data.csv"))
X <- as.matrix(df[, grep("^X", names(df))])
A <- as.integer(df$A)
Y <- as.numeric(df$Y)

pa_x <- prop.table(table(A))[as.character(A)]
```

## Run

``` r

result <- kpe(
  X = X, A = A, Y = Y, propensity = pa_x,
  n_shuffles        = 100,
  n_folds           = 6,
  contextual_policy = "linear",
  best_arm          = "best_arm_erm",
  reward_model      = "lasso",
  n_cores           = 5,
  seed              = 12314
)
summary(result)
```

The research code uses a custom learner named `joker_lasso_flat`; this
package implements a per-arm linear regression
(`contextual_policy = "linear"`) combined with a Lasso reward model
(`reward_model = "lasso"`) as the closest in-package equivalent. The
`joker_*` learners are not exported by this package.

## Results

Running the above call on the authoritative pickle under the default
leave-one-fold-out cross-fitting (`n_nuisance_folds = n_folds - 1`, so
5/6 of the data fits every nuisance) yields:

| quantity                | value            |
|-------------------------|------------------|
| `psi`                   | `0.1692`         |
| `std_error`             | `0.0231`         |
| 95% confidence interval | `[0.124, 0.214]` |
| z-statistic             | `7.56`           |
| one-sided p-value       | `1.3e-13`        |
| `policy_stability`      | `0.263`          |

For reference, this two-fold shared-nuisance scheme used here slightly
improves over the original results report in Li and Brunskill (Science,
2026). The sign of `psi` and the reject-at-0.05 decision are unchanged.

## Multi-arm learner choice

The Joke dataset has 10 actions. Among the built-in contextual-policy
strings:

- `"linear"` fits a separate OLS regression per arm and returns `argmax`
  predictions; supports any number of actions.
- `"policy_tree"` wraps
  [`policytree::policy_tree`](https://rdrr.io/pkg/policytree/man/policy_tree.html);
  supports any number of actions.
- `"policy_forest"` wraps
  [`grf::causal_forest`](https://rdrr.io/pkg/grf/man/causal_forest.html);
  in this release it supports binary treatment only and raises an
  informative error when `K > 2`.

## Notes

- The rating `Y` is normalized to the `[0, 5.0]` range prior to this
  call; `psi` is on that normalized outcome scale.
