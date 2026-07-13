# Coerce a seed to a non-zero integer for ranger/grf.

\`ranger\` (and \`grf\`) treat \`seed = 0\` as "draw a fresh random
seed", so a user-supplied \`seed = 0\` makes the forests
non-reproducible across processes (a different result on 1 core vs
forked workers). Map 0 to 1 so every forest is seeded deterministically;
all other seeds pass through unchanged.

## Usage

``` r
.nonzero_seed(seed)
```
