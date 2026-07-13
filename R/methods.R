#' Print a short summary of a kpe fit.
#'
#' @param x A \code{"kpe"} object.
#' @param digits Number of significant digits.
#' @param ... Ignored.
#' @export
print.kpe <- function(x, digits = 4, ...) {
  cat("K-Fold Personalization Estimator (", x$method, ")\n", sep = "")
  cat(sprintf("  n_samples  = %d\n", x$n_samples))
  cat(sprintf("  n_shuffles = %d, n_folds = %d\n",
              x$n_shuffles, x$n_folds))
  cat(sprintf("  psi        = %s (SE %s)\n",
              format(x$psi, digits = digits),
              format(x$std_error, digits = digits)))
  cat(sprintf("  95%% CI    = [%s, %s]\n",
              format(x$confidence_interval[1], digits = digits),
              format(x$confidence_interval[2], digits = digits)))
  cat(sprintf("  p-value    = %s (one-sided)\n",
              format(x$p_value, digits = digits)))
  if (is.finite(x$policy_stability)) {
    cat(sprintf("  policy stability = %s\n",
                format(x$policy_stability, digits = digits)))
  }
  invisible(x)
}

#' Summary of a kpe fit.
#' @param object A \code{"kpe"} object.
#' @param ... Ignored.
#' @export
summary.kpe <- function(object, ...) {
  out <- list(
    method = object$method,
    psi = object$psi,
    std_error = object$std_error,
    confidence_interval = object$confidence_interval,
    p_value = object$p_value,
    cauchy_p_value = object$cauchy_p_value,
    policy_stability = object$policy_stability,
    overall_stability = object$overall_stability,
    n_samples = object$n_samples,
    n_shuffles = object$n_shuffles,
    n_folds = object$n_folds
  )
  class(out) <- "summary.kpe"
  out
}

#' @export
print.summary.kpe <- function(x, digits = 4, ...) {
  cat("Summary of K-Fold Personalization Estimator fit (", x$method, ")\n",
      sep = "")
  cat("\n  n_samples:", x$n_samples,
      " n_shuffles:", x$n_shuffles,
      " n_folds:", x$n_folds, "\n")
  cat(sprintf("\n  Point estimate    : %s\n",
              format(x$psi, digits = digits)))
  cat(sprintf("  Standard error    : %s\n",
              format(x$std_error, digits = digits)))
  cat(sprintf("  95%% CI           : [%s, %s]\n",
              format(x$confidence_interval[1], digits = digits),
              format(x$confidence_interval[2], digits = digits)))
  cat(sprintf("  One-sided p-value : %s\n",
              format(x$p_value, digits = digits)))
  cat(sprintf("  Cauchy p-value    : %s\n",
              format(x$cauchy_p_value, digits = digits)))
  if (is.finite(x$policy_stability)) {
    cat(sprintf("\n  Contextual-policy stability : %s\n",
                format(x$policy_stability, digits = digits)))
    cat(sprintf("  Best-arm stability          : %s\n",
                format(x$overall_stability, digits = digits)))
  }
  invisible(x)
}

#' Confidence interval for a kpe fit.
#' @param object A \code{"kpe"} object.
#' @param parm Ignored (only one parameter, psi).
#' @param level Confidence level; defaults to 0.95.
#' @param ... Ignored.
#' @export
confint.kpe <- function(object, parm, level = 0.95, ...) {
  z <- stats::qnorm(1 - (1 - level) / 2)
  lo <- object$psi - z * object$std_error
  hi <- object$psi + z * object$std_error
  out <- matrix(c(lo, hi), nrow = 1,
                dimnames = list("psi", c(
                  sprintf("%.1f%%", 100 * (1 - level) / 2),
                  sprintf("%.1f%%", 100 * (1 - (1 - level) / 2)))))
  out
}

#' Extract the point estimate from a kpe fit.
#' @param object A \code{"kpe"} object.
#' @param ... Ignored.
#' @export
coef.kpe <- function(object, ...) {
  c(psi = object$psi)
}
