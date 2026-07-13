#' Best-arm builders: pick one action for everyone.
#'
#' Each builder returns a list with `fit(A, Y, propensities, n_actions)`
#' returning `self` and `predict()` returning an integer 0..K-1.
#' @keywords internal
.best_arm_ips <- function(seed = NULL) {
  function() {
    Q <- NULL
    self <- list(
      fit = function(A, Y, propensities, n_actions) {
        if (any(propensities <= 0)) {
          stop("IPS best-arm requires strictly positive propensities.")
        }
        rewards <- matrix(0, nrow = length(A), ncol = n_actions)
        idx <- cbind(seq_along(A), A + 1L)
        rewards[idx] <- Y / propensities
        Q <<- colMeans(rewards)
        self
      },
      predict = function() as.integer(which.max(Q) - 1L)
    )
    self
  }
}

.best_arm_simple <- function(seed = NULL) {
  function() {
    Q <- NULL
    self <- list(
      fit = function(A, Y, propensities, n_actions) {
        means <- rep(-Inf, n_actions)
        for (k in seq_len(n_actions) - 1L) {
          mask <- A == k
          if (any(mask)) means[k + 1L] <- mean(Y[mask])
        }
        Q <<- means
        self
      },
      predict = function() as.integer(which.max(Q) - 1L)
    )
    self
  }
}
