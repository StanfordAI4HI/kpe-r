#' K-Fold Personalization Estimator
#'
#' Point estimate, confidence interval, and one-sided p-value for the
#' personalization effect -- the expected outcome difference between the
#' best personalized policy and the best single treatment applied to
#' everyone. Implements Algorithm 1 of Li & Brunskill (2026), layered on
#' the kpe2 shared-nuisance cross-fit pass in
#' \code{\link{.single_split_kpe}}, which fits every nuisance (reward model,
#' contextual policy, best single arm, and -- when \code{is_rct = FALSE} --
#' the propensity) on a shared set of \code{n_nuisance_folds} folds and
#' evaluates the AIPW influence on the held-out block. The default is
#' leave-one-fold-out: with \code{n_folds = 6}, every nuisance is fit on 5/6
#' of the data and evaluated on the held-out 1/6, rotated six times.
#'
#' @param X Numeric matrix or data frame of covariates, shape (n, d).
#' @param A Integer vector of observed treatments, values in \eqn{\{0, \ldots,
#'   K-1\}}. Factors are auto-coerced with a message.
#' @param Y Numeric vector of observed outcomes.
#' @param propensity Scalar, length-n vector, or (n, K) matrix. A scalar
#'   broadcasts; a vector is read as \eqn{p(A_i \mid X_i)} for the observed
#'   action only. Required when \code{is_rct = TRUE} (the default); ignored
#'   when \code{is_rct = FALSE}, where the propensity is fit on the nuisance
#'   folds and \code{propensity} may be left \code{NULL}.
#' @param n_shuffles Number of Algorithm-1 repetitions (each with a
#'   different seed). Defaults to 100.
#' @param n_folds Number of folds \eqn{K} the data is partitioned into per
#'   shuffle. Must be at least 2. Defaults to 6.
#' @param n_nuisance_folds Number of folds \eqn{m} used to fit all nuisances.
#'   Defaults to \code{n_folds - 1}. The evaluation block size is
#'   \eqn{b = n\_folds - m} and must divide \code{n_folds} (non-overlapping
#'   blocks), so each sample is evaluated exactly once per shuffle. The
#'   default gives leave-one-fold-out.
#' @param is_rct Logical. If \code{TRUE} (default), \code{propensity} is the
#'   known design propensity and nothing is fit for it. If \code{FALSE}, an
#'   estimated \eqn{\hat p(a \mid x)} is fit on the nuisance folds (via
#'   \code{propensity_model}) and used in both the AIPW evaluation and the
#'   best-arm IPS.
#' @param contextual_policy One of \code{"policy_tree"} or \code{"linear"},
#'   or a list with \code{fit} and \code{predict} functions for a BYO
#'   contextual policy.
#' @param best_arm One of \code{"ips"} or \code{"simple"}, or a BYO
#'   \code{list(fit, predict)}.
#' @param reward_model One of \code{"random_forest"} or \code{"linear"},
#'   or a BYO \code{list(fit, predict)}.
#' @param propensity_model One of \code{"logistic"} or \code{"random_forest"},
#'   or a BYO \code{list(fit, predict)}. Used only when \code{is_rct = FALSE}.
#' @param policy_features Optional integer vector of 1-based column indices
#'   passed to the contextual policy. Defaults to all columns.
#' @param n_cores Number of parallel workers for the shuffle loop. Defaults
#'   to 1 (sequential).
#' @param seed Base random seed. Shuffle s uses \code{seed + s}.
#' @param verbose If \code{TRUE}, emits progress messages.
#'
#' @return An object of class \code{"kpe"} (an S3 list). See
#'   \code{\link{print.kpe}} and \code{\link{summary.kpe}}.
#'
#' @references Li Z., Brunskill E. (2026) *A Statistical Test for the
#'   Benefits of Personalizing Interventions*.
#'
#' @examples
#' set.seed(0)
#' n <- 200
#' X <- matrix(runif(n * 3, -1, 1), ncol = 3)
#' A <- rbinom(n, 1, 0.5)
#' Y <- ifelse(X[, 1] >= 0, A, 0.5 * (1 - A)) + rnorm(n, sd = 0.3)
#' fit <- kpe(X, A, Y, propensity = 0.5,
#'            n_shuffles = 4, n_folds = 6,
#'            contextual_policy = "linear",
#'            best_arm = "simple",
#'            reward_model = "linear",
#'            seed = 0)
#' print(fit)
#'
#' @export
kpe <- function(X, A, Y, propensity = NULL,
                n_shuffles = 100L, n_folds = 6L,
                n_nuisance_folds = NULL, is_rct = TRUE,
                contextual_policy = "policy_tree",
                best_arm = "ips",
                reward_model = "random_forest",
                propensity_model = "logistic",
                policy_features = NULL,
                n_cores = 1L, seed = NULL, verbose = FALSE) {
  if (isTRUE(is_rct) && is.null(propensity)) {
    stop(paste0("propensity is required when is_rct = TRUE; pass the known ",
                "design propensity, or set is_rct = FALSE to fit p_hat(a|x)."))
  }
  # When fitting propensity, the input is unused; supply a positive placeholder
  # so validation passes (the cross-fit overwrites it with the fitted p_hat).
  propensity_for_validation <- if (!isTRUE(is_rct) && is.null(propensity)) {
    0.5
  } else {
    propensity
  }
  inputs <- .check_inputs(X, A, Y, propensity_for_validation,
                          policy_features = policy_features)
  n <- nrow(inputs$X)
  base_seed <- if (is.null(seed)) 0L else as.integer(seed)

  reward_builder <- .resolve_reward(reward_model, seed = base_seed)
  policy_builder <- .resolve_policy(contextual_policy, seed = base_seed)
  best_arm_builder <- .resolve_best_arm(best_arm, seed = base_seed)
  propensity_builder <- if (isTRUE(is_rct)) {
    NULL
  } else {
    .resolve_propensity_model(propensity_model, seed = base_seed)
  }

  worker <- function(s) {
    .single_split_kpe(
      inputs,
      reward_builder = reward_builder,
      policy_builder = policy_builder,
      best_arm_builder = best_arm_builder,
      n_folds = n_folds,
      seed = base_seed + s,
      n_nuisance_folds = n_nuisance_folds,
      is_rct = is_rct,
      propensity_builder = propensity_builder
    )
  }

  shuffle_results <- .run_shuffles(worker, seq_len(n_shuffles) - 1L,
                                   n_cores = n_cores, verbose = verbose)

  psi_hats <- vapply(shuffle_results, function(r) r$psi_hat, numeric(1))
  sigma_hats <- vapply(shuffle_results, function(r) r$sigma_hat, numeric(1))

  agg <- .aggregate_shuffles(psi_hats, sigma_hats, n_samples = n)

  policy_mat <- do.call(rbind, lapply(shuffle_results, `[[`, "predicted_policy_actions"))
  overall_mat <- do.call(rbind, lapply(shuffle_results, `[[`, "predicted_overall_actions"))
  policy_stability <- .prediction_stability(policy_mat)
  overall_stability <- .best_arm_stability(overall_mat)

  res <- list(
    psi = agg$psi,
    std_error = agg$std_error,
    confidence_interval = agg$confidence_interval,
    p_value = agg$p_value,
    psi_per_shuffle = agg$psi_per_shuffle,
    sigma_per_shuffle = agg$sigma_per_shuffle,
    p_value_per_shuffle = agg$p_value_per_shuffle,
    cauchy_p_value = agg$cauchy_p_value,
    policy_stability = policy_stability,
    overall_stability = overall_stability,
    # (S, n) integer matrices retained so downstream code can recompute
    # any per-shuffle figure (Fig 3 CIs / z-CDFs) or any stability metric
    # post hoc, without re-running the (often hours-long) cross-fit loop.
    policy_actions_per_shuffle = policy_mat,
    overall_actions_per_shuffle = overall_mat,
    # Back-compat: canonical 1-D view = last shuffle's action vector.
    predicted_policy_actions = policy_mat[nrow(policy_mat), ],
    predicted_overall_actions = overall_mat[nrow(overall_mat), ],
    method = "kpe",
    n_samples = n,
    n_shuffles = as.integer(n_shuffles),
    n_folds = as.integer(n_folds)
  )
  class(res) <- c("kpe", "list")
  res
}


#' Run the shuffle loop with optional parallelism via `future`.
#' @keywords internal
.run_shuffles <- function(fn, seeds, n_cores = 1L, verbose = FALSE) {
  if (n_cores > 1L) {
    if (!requireNamespace("future.apply", quietly = TRUE)) {
      stop("n_cores > 1 requires the `future.apply` package.")
    }
    if (!requireNamespace("future", quietly = TRUE)) {
      stop("n_cores > 1 requires the `future` package.")
    }
    # Prefer fork-based multicore where supported (macOS/Linux from a
    # non-interactive session): forked workers inherit the parent's loaded
    # functions, .libPaths, and options, which matters when the package is
    # flat-sourced rather than installed. Fall back to multisession (Windows).
    use_fork <- isTRUE(tryCatch(parallelly::supportsMulticore(),
                                error = function(e) FALSE))
    strategy <- if (use_fork) future::multicore else future::multisession
    old_plan <- future::plan(strategy, workers = as.integer(n_cores))
    on.exit(future::plan(old_plan), add = TRUE)
    results <- future.apply::future_lapply(
      seeds, fn,
      future.seed = TRUE
    )
  } else {
    results <- lapply(seeds, fn)
  }
  results
}
