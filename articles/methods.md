# Methods

This vignette summarizes the K-Fold Personalization Estimator.

## References:

- Zhaoqi Li, Emma Brunskill, A statistical test for the benefits of
  personalizing interventions. Science 393, eaeb9506 (2026). DOI:
  [10.1126/science.aeb9506](https://doi.org/10.1126/science.aeb9506)
- 2-fold variant detailed
  [here](https://drive.google.com/file/d/1mmFIdJEQCKhO9Z2flWloWx3ZRQB4P3r4/view)

## Target

Given tuples $`(X_i, A_i, Y_i)`$ with known or estimated propensities
$`p(A_i \mid X_i)`$, the personalization effect is defined as

``` math
\psi = \mathbb{E}\!\left[Y \mid \pi^\star(X)\right]
       - \max_{a}\,\mathbb{E}\!\left[Y \mid A = a\right],
```

where $`\pi^\star`$ is the optimal personalized policy and the
right-hand term is the expected outcome under the best single treatment
applied to every individual.

## Algorithm 2: per-shuffle cross-fit (kpe2 shared-nuisance variant)

Partition the $`n`$ rows into $`K =`$`n_folds` folds. Choose
$`m =`$`n_nuisance_folds` folds on which to fit the nuisances (default
$`m = K - 1`$); the evaluation block size is $`b = K - m`$ and must
divide $`K`$, so the folds tile into $`G = K / b`$ non-overlapping
evaluation blocks. For each block $`g`$:

1.  Fit **all** nuisances — the reward model $`m(x, a)`$, the contextual
    policy $`\pi(x)`$, the best single arm $`\pi_0`$, and (when
    `is_rct = FALSE`) the propensity $`\hat p(a \mid x)`$ — on the $`m`$
    folds *outside* block $`g`$.
2.  Evaluate the AIPW influence function (Eq. S17) on the $`b`$ folds of
    block $`g`$:

``` math
\psi_i = m(X, \pi(X)) - m(X, \pi_0)
        + \frac{\mathbf{1}\{A = \pi(X), \pi_0 \neq \pi(X)\}
              - \mathbf{1}\{A = \pi_0, \pi_0 \neq \pi(X)\}}
             {p(A \mid X)}\,(Y - m(X, A)).
```

Concatenating the per-block $`\psi`$ vectors across all $`G`$ blocks
yields a length-$`n`$ vector in which each sample is evaluated exactly
once; the shuffle-level summary is $`\hat\psi_s = \text{mean}`$ and
$`\hat\sigma_s = \text{std}`$.

Unlike the original Algorithm 2 (Li and Brunskill, Science 2026) — which
fits the policy and reward models on *disjoint* subsets of the
non-evaluation folds — kpe2 fits every nuisance on the same $`m`$ folds.
The default $`m = K - 1`$ gives $`b = 1`$ and $`G = K`$:
leave-one-fold-out, fitting every nuisance on $`K - 1`$ folds and
evaluating on the remaining one, rotated $`K`$ times (with $`K = 6`$,
that is 5/6 of the data to fit and 1/6 to evaluate). When
`is_rct = TRUE` (the default), $`p(A \mid X)`$ above is the known design
propensity and nothing is fit for it; when `is_rct = FALSE`, the fitted
$`\hat p(a \mid x)`$ is used in both the influence evaluation and the
best-arm comparison.

## Algorithm 1: aggregation across shuffles

Algorithm 2 is repeated for $`S`$ random shuffles, and the per-shuffle
$`(\hat\psi_s, \hat\sigma_s)`$ pairs are aggregated via

``` math
\hat\psi = \tfrac{1}{S}\sum_s \hat\psi_s,
\qquad
\widehat{\operatorname{Var}}(\hat\psi) =
\tfrac{1}{S}\sum_s\!\left(\hat\sigma_s^2 + (\hat\psi_s - \hat\psi)^2\right)\!\Big/\,n.
```

The first term accounts for within-shuffle influence variance; the
second term accounts for across-shuffle variability introduced by sample
splitting.

The one-sided upper-tail t-statistic is
$`t = \hat\psi / \sqrt{\widehat{\operatorname{Var}}(\hat\psi)}`$, and
the reported `p_value` is the corresponding upper-tail probability under
$`t_{n-1}`$. The `confidence_interval` is the 95% Wald interval
$`\hat\psi \pm 1.96 \sqrt{\widehat{\operatorname{Var}}(\hat\psi)}`$.

## Stability diagnostic

`policy_stability` is the fraction of samples for which every shuffle’s
contextual policy predicted the same action; its range is $`[0, 1]`$.
`overall_stability` is the analogous quantity for the best-arm policy.
