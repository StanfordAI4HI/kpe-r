# Validate kpe inputs and return a canonical list.

Coerces X, A, Y, propensity into the shapes the cross-fit loop expects.
Mirrors \`kpe-py/src/kpe/io.py::validate_inputs\`: X becomes a matrix, A
an integer 0..K-1, Y numeric, propensity an (n, K) matrix, and X_policy
is X sliced by \`policy_features\` (or X itself).

## Usage

``` r
.check_inputs(X, A, Y, propensity, policy_features = NULL)
```

## Arguments

- X:

  matrix / data.frame / numeric vector of covariates.

- A:

  integer vector (or factor, auto-coerced with a message).

- Y:

  numeric vector.

- propensity:

  scalar, length-n vector, or (n, K) matrix.

- policy_features:

  optional integer vector of 1-based column indices.
