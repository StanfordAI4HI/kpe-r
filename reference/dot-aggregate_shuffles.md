# Across-shuffle aggregation: Algorithm 1 variance decomposition + Cauchy.

Given S per-shuffle (psi_hat, sigma_hat) pairs,

## Usage

``` r
.aggregate_shuffles(psi_hats, sigma_hats, n_samples, alpha = 0.05)
```

## Details

psi = mean_s psi_hat var_total = mean_s (sigma_hat^2 + (psi_hat -
psi)^2) se = sqrt(var_total / n) t_stat = psi / se p_value = one-sided
upper-tail p-value under t_n-1

Per-shuffle one-sided p-values are also produced from a standard-normal
approximation and fed into the Cauchy combination test.
