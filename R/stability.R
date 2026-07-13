#' Fraction of samples for which all shuffles agree on the predicted action.
#'
#' Matches the paper's Table S1 *policy* stability:
#' \eqn{1 - (1/|X|) \sum_x I(\exists s, s' : \pi_s(x) \neq \pi_{s'}(x))}.
#' Use this on per-sample policy-action matrices, not on the best-arm matrix
#' (each best-arm row is broadcast-constant so this would collapse to 0 or 1;
#' use [.best_arm_stability] instead).
#'
#' @param action_matrix (S, n) integer matrix; row s holds one shuffle's
#'   per-sample predicted action.
#' @keywords internal
.prediction_stability <- function(action_matrix) {
  if (!is.matrix(action_matrix)) {
    stop(".prediction_stability expects a matrix.")
  }
  n <- ncol(action_matrix)
  if (n == 0L) return(1)
  unstable <- vapply(seq_len(n), function(j) {
    length(unique(action_matrix[, j])) >= 2L
  }, logical(1))
  1 - mean(unstable)
}


#' Share of shuffles whose best-arm choice equals the modal best arm.
#'
#' Matches the paper's Table S1 *best-arm* stability ("percentage of the
#' occurrence of the most frequently output best intervention across splits
#' and folds"). For (S, n) input each row is reduced to its modal action
#' (defensive against non-constant rows); the return value is the largest
#' cross-shuffle action share. Unanimously chosen best arm returns 1; an
#' even split across K arms returns 1/K. 1-D input is treated as a single
#' vector of best-arms.
#'
#' @param action_matrix integer matrix (S, n) or integer vector.
#' @keywords internal
.best_arm_stability <- function(action_matrix) {
  if (is.matrix(action_matrix)) {
    s_runs <- nrow(action_matrix)
    if (s_runs == 0L) return(1)
    per_run <- vapply(seq_len(s_runs), function(s) {
      tab <- tabulate(as.integer(action_matrix[s, ]) + 1L)
      as.integer(which.max(tab) - 1L)
    }, integer(1))
  } else if (is.vector(action_matrix)) {
    if (length(action_matrix) == 0L) return(1)
    per_run <- as.integer(action_matrix)
  } else {
    stop(".best_arm_stability expects a matrix or integer vector.")
  }
  tab <- tabulate(per_run + 1L)
  max(tab) / length(per_run)
}
