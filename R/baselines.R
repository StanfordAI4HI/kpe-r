#' Per-shuffle TrainEval worker: 50/50 split AIPW on one shuffle seed.
#'
#' Mirrors `kpe-py/src/kpe/core/baselines.py::single_split_train_eval`.
#' Each shuffle trains reward/policy/best-arm on a random half of the rows
#' and scores the AIPW influence function on the held-out half.
#'
#' @param order_override Optional 1-based integer vector of row ordering to
#'   use instead of the seeded `sample.int`; lets the Python-parity test
#'   inject the same permutation numpy's default_rng produced.
#' @keywords internal
.single_split_train_eval <- function(inputs, reward_builder, policy_builder,
                                     best_arm_builder, seed,
                                     order_override = NULL) {
  n <- nrow(inputs$X)
  order <- if (is.null(order_override)) {
    prev <- if (exists(".Random.seed", envir = .GlobalEnv)) {
      get(".Random.seed", envir = .GlobalEnv)
    } else NULL
    set.seed(seed)
    o <- sample.int(n)
    if (!is.null(prev)) assign(".Random.seed", prev, envir = .GlobalEnv)
    o
  } else {
    order_override
  }
  mid <- n %/% 2L
  train_idx <- order[seq_len(mid)]
  test_idx <- order[(mid + 1L):n]

  A_tr <- inputs$A[train_idx]
  Y_tr <- inputs$Y[train_idx]
  X_tr <- inputs$X[train_idx, , drop = FALSE]
  X_pol_tr <- inputs$X_policy[train_idx, , drop = FALSE]
  prop_tr_obs <- inputs$propensity[cbind(train_idx, A_tr + 1L)]

  reward_model <- reward_builder()
  XA_tr <- cbind(X_tr, as.numeric(A_tr))
  reward_model$fit(XA_tr, Y_tr)

  contextual_policy <- policy_builder()
  contextual_policy$fit(X_pol_tr, A_tr, Y_tr, n_actions = inputs$n_actions)

  best_arm <- best_arm_builder()
  best_arm$fit(A_tr, Y_tr, prop_tr_obs, n_actions = inputs$n_actions)

  X_te <- inputs$X[test_idx, , drop = FALSE]
  A_te <- inputs$A[test_idx]
  Y_te <- inputs$Y[test_idx]
  X_pol_te <- inputs$X_policy[test_idx, , drop = FALSE]
  prop_te_obs <- inputs$propensity[cbind(test_idx, A_te + 1L)]

  vals <- .aipw_influence(
    X = X_te, A = A_te, Y = Y_te, X_policy = X_pol_te,
    propensity_observed = prop_te_obs,
    reward_model = reward_model,
    contextual_policy = contextual_policy,
    best_arm = best_arm
  )

  policy_full <- rep(-1L, n)
  overall_full <- rep(-1L, n)
  policy_full[test_idx] <- vals$policy_action
  overall_full[test_idx] <- vals$overall_action

  list(
    psi_per_sample = vals$psi,
    psi_hat = mean(vals$psi),
    sigma_hat = .popsd(vals$psi),
    predicted_policy_actions = policy_full,
    predicted_overall_actions = overall_full
  )
}


#' Per-shuffle PAPD worker: K-fold rotation of the centered IPW statistic.
#'
#' Implements Eq. S18 of Li & Brunskill (2026). No reward model is fit;
#' centering is on the test-fold mean(Y).
#'
#' @param folds_override Optional list of length n_folds with per-fold 1-based
#'   row indices, used by the Python-parity test.
#' @keywords internal
.single_split_papd <- function(inputs, policy_builder, best_arm_builder,
                               n_folds, seed, folds_override = NULL) {
  n <- nrow(inputs$X)
  folds <- if (is.null(folds_override)) {
    .fold_indices(n, n_folds, seed)
  } else {
    folds_override
  }
  n_actions <- inputs$n_actions

  psi_per_sample <- numeric(n)
  pred_policy <- integer(n)
  pred_overall <- integer(n)

  for (i in seq_len(n_folds)) {
    test_idx <- folds[[i]]
    train_mask <- rep(TRUE, n)
    train_mask[test_idx] <- FALSE
    train_idx <- which(train_mask)

    A_tr <- inputs$A[train_idx]
    Y_tr <- inputs$Y[train_idx]
    X_pol_tr <- inputs$X_policy[train_idx, , drop = FALSE]
    prop_tr_obs <- inputs$propensity[cbind(train_idx, A_tr + 1L)]

    contextual_policy <- policy_builder()
    contextual_policy$fit(X_pol_tr, A_tr, Y_tr, n_actions = n_actions)

    best_arm <- best_arm_builder()
    best_arm$fit(A_tr, Y_tr, prop_tr_obs, n_actions = n_actions)

    X_pol_te <- inputs$X_policy[test_idx, , drop = FALSE]
    A_te <- inputs$A[test_idx]
    Y_te <- inputs$Y[test_idx]
    prop_te_obs <- inputs$propensity[cbind(test_idx, A_te + 1L)]

    policy_action <- as.integer(contextual_policy$predict(X_pol_te))
    best_single <- as.integer(best_arm$predict())
    overall_actions <- rep(best_single, length(A_te))

    different <- as.numeric(policy_action != overall_actions)
    indicator <- as.numeric(A_te == policy_action) * different -
                 as.numeric(A_te == overall_actions) * different
    mean_Y_te <- mean(Y_te)
    psi_fold <- indicator / prop_te_obs * (Y_te - mean_Y_te)

    psi_per_sample[test_idx] <- psi_fold
    pred_policy[test_idx] <- policy_action
    pred_overall[test_idx] <- overall_actions
  }

  list(
    psi_per_sample = psi_per_sample,
    psi_hat = mean(psi_per_sample),
    sigma_hat = .popsd(psi_per_sample),
    predicted_policy_actions = pred_policy,
    predicted_overall_actions = pred_overall
  )
}


#' TrainEval baseline: 50/50 split AIPW repeated across shuffles.
#'
#' Single-split AIPW: each shuffle trains reward, contextual policy, and
#' best-arm on a random half of the rows and scores the AIPW influence
#' function on the held-out half. Faster than \code{\link{kpe}} but the
#' effective sample size for the CI is n/2 and stability across shuffles is
#' undefined (each shuffle sees a different random half), so
#' `policy_stability` is returned as \code{NaN}.
#'
#' @inheritParams kpe
#' @return A \code{"kpe"} S3 object. \code{n_folds} is reported as 2; any
#'   value passed for \code{n_folds} is ignored.
#' @export
train_eval <- function(X, A, Y, propensity,
                       n_shuffles = 100L, n_folds = 2L,
                       contextual_policy = "policy_tree",
                       best_arm = "ips",
                       reward_model = "random_forest",
                       policy_features = NULL,
                       n_cores = 1L, seed = NULL, verbose = FALSE) {
  inputs <- .check_inputs(X, A, Y, propensity, policy_features = policy_features)
  n <- nrow(inputs$X)
  base_seed <- if (is.null(seed)) 0L else as.integer(seed)

  reward_builder <- .resolve_reward(reward_model, seed = base_seed)
  policy_builder <- .resolve_policy(contextual_policy, seed = base_seed)
  best_arm_builder <- .resolve_best_arm(best_arm, seed = base_seed)

  worker <- function(s) {
    .single_split_train_eval(
      inputs,
      reward_builder = reward_builder,
      policy_builder = policy_builder,
      best_arm_builder = best_arm_builder,
      seed = base_seed + s
    )
  }
  shuffle_results <- .run_shuffles(worker, seq_len(n_shuffles) - 1L,
                                   n_cores = n_cores, verbose = verbose)

  psi_hats <- vapply(shuffle_results, function(r) r$psi_hat, numeric(1))
  sigma_hats <- vapply(shuffle_results, function(r) r$sigma_hat, numeric(1))
  # TrainEval uses half the data per shuffle; effective n for the
  # t-denominator is n/2.
  agg <- .aggregate_shuffles(psi_hats, sigma_hats, n_samples = n %/% 2L)

  policy_mat <- do.call(rbind, lapply(shuffle_results, `[[`, "predicted_policy_actions"))
  overall_mat <- do.call(rbind, lapply(shuffle_results, `[[`, "predicted_overall_actions"))
  res <- list(
    psi = agg$psi,
    std_error = agg$std_error,
    confidence_interval = agg$confidence_interval,
    p_value = agg$p_value,
    psi_per_shuffle = agg$psi_per_shuffle,
    sigma_per_shuffle = agg$sigma_per_shuffle,
    p_value_per_shuffle = agg$p_value_per_shuffle,
    cauchy_p_value = agg$cauchy_p_value,
    policy_stability = NaN,
    overall_stability = NaN,
    # (S, n) integer matrices retained so downstream code can recompute
    # any per-shuffle figure or stability metric post hoc.
    policy_actions_per_shuffle = policy_mat,
    overall_actions_per_shuffle = overall_mat,
    predicted_policy_actions = policy_mat[nrow(policy_mat), ],
    predicted_overall_actions = overall_mat[nrow(overall_mat), ],
    method = "train_eval",
    n_samples = n,
    n_shuffles = as.integer(n_shuffles),
    n_folds = 2L
  )
  class(res) <- c("kpe", "list")
  res
}


#' PAPD baseline (Imai's Population Average Prescriptive Difference, centered).
#'
#' 3-fold rotation of the centered IPW statistic from Eq. S18 of
#' Li & Brunskill (2026). No reward model is fit; the \code{reward_model}
#' argument is accepted for API symmetry with \code{\link{kpe}} and is
#' ignored. \code{n_folds} is also ignored -- PAPD always uses 3 folds.
#'
#' @inheritParams kpe
#' @return A \code{"kpe"} S3 object.
#' @export
papd <- function(X, A, Y, propensity,
                 n_shuffles = 100L, n_folds = 3L,
                 contextual_policy = "policy_tree",
                 best_arm = "ips",
                 reward_model = "random_forest",
                 policy_features = NULL,
                 n_cores = 1L, seed = NULL, verbose = FALSE) {
  # reward_model accepted but unused; n_folds fixed at 3 per paper's design.
  inputs <- .check_inputs(X, A, Y, propensity, policy_features = policy_features)
  n <- nrow(inputs$X)
  base_seed <- if (is.null(seed)) 0L else as.integer(seed)
  papd_folds <- 3L

  policy_builder <- .resolve_policy(contextual_policy, seed = base_seed)
  best_arm_builder <- .resolve_best_arm(best_arm, seed = base_seed)

  worker <- function(s) {
    .single_split_papd(
      inputs,
      policy_builder = policy_builder,
      best_arm_builder = best_arm_builder,
      n_folds = papd_folds,
      seed = base_seed + s
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
    # any per-shuffle figure or stability metric post hoc.
    policy_actions_per_shuffle = policy_mat,
    overall_actions_per_shuffle = overall_mat,
    predicted_policy_actions = policy_mat[nrow(policy_mat), ],
    predicted_overall_actions = overall_mat[nrow(overall_mat), ],
    method = "papd",
    n_samples = n,
    n_shuffles = as.integer(n_shuffles),
    n_folds = papd_folds
  )
  class(res) <- c("kpe", "list")
  res
}
