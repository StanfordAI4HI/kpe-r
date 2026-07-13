#' Build the n_folds fold index list for a single shuffle.
#'
#' Mirrors scikit-learn's `KFold(n_splits, shuffle=TRUE, random_state=seed)`:
#' shuffle the row indices with a seeded RNG, split into n_folds roughly-equal
#' contiguous blocks. We implement this by hand so the Python and R packages
#' can be kept bitwise-aligned (via folds_override) without pinning to any
#' single RNG library.
#'
#' @keywords internal
.fold_indices <- function(n, n_folds, seed) {
  prev <- if (exists(".Random.seed", envir = .GlobalEnv)) {
    get(".Random.seed", envir = .GlobalEnv)
  } else NULL
  # Force the RNG kind, not just the seed: under parallel execution
  # `future.apply(future.seed = TRUE)` switches the RNG kind to "L'Ecuyer-CMRG"
  # in the workers, so a bare `set.seed(seed)` (kind = current) would draw a
  # DIFFERENT permutation than the sequential "Mersenne-Twister" default and the
  # fold partition would depend on n_cores. Pinning the kind makes the split
  # identical whether run on 1 core or many. Restoring `prev` below also restores
  # the caller's original kind.
  set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion",
           sample.kind = "Rejection")
  order <- sample.int(n)
  if (!is.null(prev)) {
    assign(".Random.seed", prev, envir = .GlobalEnv)
  }
  fold_sizes <- rep.int(n %/% n_folds, n_folds)
  fold_sizes[seq_len(n %% n_folds)] <- fold_sizes[seq_len(n %% n_folds)] + 1L
  starts <- c(0L, cumsum(fold_sizes))
  lapply(seq_len(n_folds), function(k) order[(starts[k] + 1L):starts[k + 1L]])
}


#' Resolve the kpe2 fold split: m nuisance folds and eval-block size b = K - m.
#' Validates that b divides K (non-overlapping evaluation blocks, "option A").
#' @keywords internal
.resolve_split_kpe2 <- function(n_folds, n_nuisance_folds) {
  K <- as.integer(n_folds)
  if (K < 2L) stop("n_folds must be >= 2.")
  m <- if (is.null(n_nuisance_folds)) K - 1L else as.integer(n_nuisance_folds)
  if (m < 1L || m > K - 1L) {
    stop(sprintf("n_nuisance_folds must be in [1, %d]; got %d", K - 1L, m))
  }
  b <- K - m
  if (K %% b != 0L) {
    stop(sprintf(paste0("evaluation block size b = n_folds - n_nuisance_folds ",
                        "= %d must divide n_folds = %d (non-overlapping ",
                        "blocks, option A)."), b, K))
  }
  list(m = m, b = b)
}


#' Run one kpe2 shared-nuisance cross-fit pass.
#'
#' Partition the rows into n_folds folds. Tile them into K/b non-overlapping
#' evaluation blocks of size b = n_folds - n_nuisance_folds. For each block:
#' fit ALL nuisances (reward model, contextual policy, best single arm, and --
#' when is_rct = FALSE -- the propensity p(a|x)) on the other m = n_nuisance_folds
#' folds, then evaluate the AIPW influence on the block. Each sample is
#' evaluated exactly once per shuffle. Default n_nuisance_folds = n_folds - 1
#' gives leave-one-fold-out.
#'
#' @param folds_override Optional list of length n_folds, each a vector of
#'   1-based row indices. Used by the cross-language parity test to inject
#'   sklearn's KFold shuffle so both languages operate on identical folds.
#' @keywords internal
.single_split_kpe <- function(inputs, reward_builder, policy_builder,
                              best_arm_builder, n_folds, seed,
                              n_nuisance_folds = NULL, is_rct = TRUE,
                              propensity_builder = NULL,
                              folds_override = NULL) {
  n <- nrow(inputs$X)
  n_actions <- inputs$n_actions
  sp <- .resolve_split_kpe2(n_folds, n_nuisance_folds)
  b <- sp$b

  folds <- if (is.null(folds_override)) {
    .fold_indices(n, n_folds, seed)
  } else {
    folds_override
  }
  n_blocks <- n_folds %/% b

  psi_per_sample <- numeric(n)
  pred_policy <- integer(n)
  pred_overall <- integer(n)

  for (g in seq_len(n_blocks) - 1L) {
    eval_fold_ids <- (g * b + 1L):((g + 1L) * b)
    eval_idx <- unlist(folds[eval_fold_ids])
    nuis_fold_ids <- setdiff(seq_len(n_folds), eval_fold_ids)
    nuis_idx <- unlist(folds[nuis_fold_ids])

    A_nu <- inputs$A[nuis_idx]
    Y_nu <- inputs$Y[nuis_idx]
    X_nu <- inputs$X[nuis_idx, , drop = FALSE]
    Xpol_nu <- inputs$X_policy[nuis_idx, , drop = FALSE]

    X_te <- inputs$X[eval_idx, , drop = FALSE]
    A_te <- inputs$A[eval_idx]
    Y_te <- inputs$Y[eval_idx]
    Xpol_te <- inputs$X_policy[eval_idx, , drop = FALSE]

    # Observed-action propensity: known (RCT) or fit on the nuisance folds.
    if (is_rct || is.null(propensity_builder)) {
      prop_nu_obs <- inputs$propensity[cbind(nuis_idx, A_nu + 1L)]
      prop_te_obs <- inputs$propensity[cbind(eval_idx, A_te + 1L)]
    } else {
      prop_model <- propensity_builder()
      prop_model$fit(X_nu, A_nu, n_actions = n_actions)
      P_nu <- prop_model$predict_proba(X_nu)
      P_te <- prop_model$predict_proba(X_te)
      prop_nu_obs <- pmax(P_nu[cbind(seq_along(A_nu), A_nu + 1L)], 1e-6)
      prop_te_obs <- pmax(P_te[cbind(seq_along(A_te), A_te + 1L)], 1e-6)
    }

    reward_model <- reward_builder()
    XA_nu <- cbind(X_nu, as.numeric(A_nu))
    reward_model$fit(XA_nu, Y_nu)

    contextual_policy <- policy_builder()
    contextual_policy$fit(Xpol_nu, A_nu, Y_nu, n_actions = n_actions)

    best_arm <- best_arm_builder()
    best_arm$fit(A_nu, Y_nu, prop_nu_obs, n_actions = n_actions)

    vals <- .aipw_influence(
      X = X_te, A = A_te, Y = Y_te, X_policy = Xpol_te,
      propensity_observed = prop_te_obs,
      reward_model = reward_model,
      contextual_policy = contextual_policy,
      best_arm = best_arm
    )

    psi_per_sample[eval_idx] <- vals$psi
    pred_policy[eval_idx] <- vals$policy_action
    pred_overall[eval_idx] <- vals$overall_action
  }

  list(
    psi_per_sample = psi_per_sample,
    psi_hat = mean(psi_per_sample),
    sigma_hat = .popsd(psi_per_sample),
    predicted_policy_actions = pred_policy,
    predicted_overall_actions = pred_overall
  )
}


#' Population (ddof=0) standard deviation, matching numpy.std default.
#' @keywords internal
.popsd <- function(x) sqrt(mean((x - mean(x))^2))
