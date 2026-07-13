# One-hot encode an integer action vector with the baseline arm (0) dropped. Returns an (length(a) x (n_actions - 1)) numeric matrix, mirroring econml's treatment encoding (baseline category omitted). For binary treatments this is a single column 1a == 1.

One-hot encode an integer action vector with the baseline arm (0)
dropped. Returns an (length(a) x (n_actions - 1)) numeric matrix,
mirroring econml's treatment encoding (baseline category omitted). For
binary treatments this is a single column 1a == 1.

## Usage

``` r
.onehot_drop_baseline(a, n_actions)
```
