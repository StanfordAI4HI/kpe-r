#' String -> builder resolvers for reward, policy, and best-arm learners.
#'
#' BYO path: users may pass a list with `fit` and `predict` functions. The
#' resolver wraps it so the same instance is returned fresh per fold.
#' @keywords internal
.resolve_reward <- function(spec, seed = NULL) {
  if (is.character(spec)) {
    builder <- switch(spec,
      random_forest = .reward_random_forest(seed = seed),
      linear        = .reward_linear(seed = seed),
      ridge         = .reward_ridge(seed = seed),
      lasso         = .reward_lasso(seed = seed),
      stop(sprintf(
        "unknown reward_model \"%s\". Known: random_forest, linear, ridge, lasso.",
        spec))
    )
    return(builder)
  }
  if (is.list(spec) && all(c("fit", "predict") %in% names(spec))) {
    return(function() spec)
  }
  stop("reward_model must be a string or a list(fit, predict) object.")
}

#' @keywords internal
.resolve_policy <- function(spec, seed = NULL) {
  if (is.character(spec)) {
    builder <- switch(spec,
      policy_tree   = .policy_tree(seed = seed),
      policy_forest = .policy_forest(seed = seed),
      causal_forest = .policy_forest(seed = seed),
      linear        = .policy_linear(seed = seed),
      stop(sprintf(
        "unknown contextual_policy \"%s\". Known: policy_tree, policy_forest, linear.",
        spec))
    )
    return(builder)
  }
  if (is.list(spec) && all(c("fit", "predict") %in% names(spec))) {
    return(function() spec)
  }
  stop("contextual_policy must be a string or a list(fit, predict) object.")
}

#' @keywords internal
.resolve_best_arm <- function(spec, seed = NULL) {
  if (is.character(spec)) {
    builder <- switch(spec,
      ips          = .best_arm_ips(seed = seed),
      best_arm_erm = .best_arm_ips(seed = seed),
      simple       = .best_arm_simple(seed = seed),
      simple_best_arm = .best_arm_simple(seed = seed),
      stop(sprintf(
        "unknown best_arm \"%s\". Known: ips, simple.", spec))
    )
    return(builder)
  }
  if (is.list(spec) && all(c("fit", "predict") %in% names(spec))) {
    return(function() spec)
  }
  stop("best_arm must be a string or a list(fit, predict) object.")
}

#' Resolve a propensity-model spec (used only when is_rct = FALSE). Returns a
#' builder producing a list with `fit(X, A, n_actions)` and `predict_proba(X)`.
#' @keywords internal
.resolve_propensity_model <- function(spec, seed = NULL) {
  if (is.character(spec)) {
    builder <- switch(spec,
      logistic      = .propensity_logistic(seed = seed),
      random_forest = .propensity_forest(seed = seed),
      stop(sprintf(
        "unknown propensity_model \"%s\". Known: logistic, random_forest.",
        spec))
    )
    return(builder)
  }
  if (is.list(spec) && all(c("fit", "predict_proba") %in% names(spec))) {
    return(function() spec)
  }
  stop("propensity_model must be a string or a list(fit, predict_proba) object.")
}
