#' Validate kpe inputs and return a canonical list.
#'
#' Coerces X, A, Y, propensity into the shapes the cross-fit loop expects.
#' Mirrors `kpe-py/src/kpe/io.py::validate_inputs`: X becomes a matrix,
#' A an integer 0..K-1, Y numeric, propensity an (n, K) matrix, and
#' X_policy is X sliced by `policy_features` (or X itself).
#'
#' @param X matrix / data.frame / numeric vector of covariates.
#' @param A integer vector (or factor, auto-coerced with a message).
#' @param Y numeric vector.
#' @param propensity scalar, length-n vector, or (n, K) matrix.
#' @param policy_features optional integer vector of 1-based column indices.
#' @keywords internal
.check_inputs <- function(X, A, Y, propensity, policy_features = NULL) {
  X <- .as_matrix(X, name = "X")
  n <- nrow(X)

  if (is.factor(A)) {
    message("kpe: coercing factor A to 0-based integer actions.")
    A <- as.integer(A) - 1L
  }
  if (!is.numeric(A) && !is.integer(A)) {
    stop("A must be integer or numeric-integer-valued.")
  }
  A <- as.integer(A)
  if (length(A) != n) stop(sprintf("A must have length %d, got %d.", n, length(A)))
  if (any(A < 0L)) stop("A must contain non-negative integers starting at 0.")
  K <- max(A) + 1L
  if (K < 2L) stop("A must contain at least two distinct actions.")

  Y <- as.numeric(Y)
  if (length(Y) != n) stop(sprintf("Y must have length %d, got %d.", n, length(Y)))
  if (!all(is.finite(Y))) stop("Y contains non-finite values.")

  prop_mat <- .resolve_propensity(propensity, A, K, n)

  if (is.null(policy_features)) {
    X_policy <- X
  } else {
    cols <- as.integer(policy_features)
    if (min(cols) < 1L || max(cols) > ncol(X)) {
      stop(sprintf(
        "policy_features out of range for X with %d columns", ncol(X)))
    }
    X_policy <- X[, cols, drop = FALSE]
  }

  list(X = X, A = A, Y = Y, propensity = prop_mat,
       X_policy = X_policy, n_actions = K)
}


#' Convert propensity spec into an (n, K) matrix.
#' @keywords internal
.resolve_propensity <- function(propensity, A, K, n) {
  if (length(propensity) == 1L) {
    p <- as.numeric(propensity)
    if (!is.finite(p) || p <= 0) {
      stop("propensity for the observed action must be positive and finite.")
    }
    return(matrix(p, nrow = n, ncol = K))
  }
  if (is.matrix(propensity)) {
    if (!all(dim(propensity) == c(n, K))) {
      stop(sprintf(
        "2-D propensity must have shape (%d, %d), got (%d, %d)",
        n, K, nrow(propensity), ncol(propensity)))
    }
    observed <- propensity[cbind(seq_len(n), A + 1L)]
    if (any(observed <= 0) || !all(is.finite(observed))) {
      stop("propensity for the observed action must be positive and finite.")
    }
    return(propensity)
  }
  if (is.numeric(propensity)) {
    if (length(propensity) != n) {
      stop(sprintf("1-D propensity must have length %d, got %d",
                   n, length(propensity)))
    }
    prop_mat <- matrix(NA_real_, nrow = n, ncol = K)
    for (k in seq_len(K) - 1L) {
      mask <- A == k
      prop_mat[mask, k + 1L] <- propensity[mask]
    }
    observed <- prop_mat[cbind(seq_len(n), A + 1L)]
    if (any(observed <= 0) || !all(is.finite(observed))) {
      stop("propensity for the observed action must be positive and finite.")
    }
    return(prop_mat)
  }
  stop("propensity must be a scalar, length-n vector, or (n, K) matrix.")
}


#' Coerce a seed to a non-zero integer for ranger/grf.
#'
#' `ranger` (and `grf`) treat `seed = 0` as "draw a fresh random seed", so a
#' user-supplied `seed = 0` makes the forests non-reproducible across processes
#' (a different result on 1 core vs forked workers). Map 0 to 1 so every forest
#' is seeded deterministically; all other seeds pass through unchanged.
#' @keywords internal
.nonzero_seed <- function(seed) {
  s <- as.integer(seed)
  if (length(s) == 1L && !is.na(s) && s == 0L) 1L else s
}


#' Coerce to a numeric matrix, preserving row count.
#' @keywords internal
.as_matrix <- function(X, name) {
  if (is.data.frame(X)) X <- as.matrix(X)
  if (is.null(dim(X))) X <- matrix(as.numeric(X), ncol = 1L)
  if (!is.matrix(X)) stop(sprintf("%s must be a matrix or data frame.", name))
  storage.mode(X) <- "double"
  if (!all(is.finite(X))) {
    stop(sprintf("%s contains non-finite values (NaN or inf).", name))
  }
  X
}
