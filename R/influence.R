#' AIPW influence function for the personalization effect.
#'
#' Equation S17 of Li & Brunskill (2026): per-sample psi combining a
#' plug-in reward-model difference with an IPW correction that centers the
#' estimator on the held-out fold. Mirrors
#' `kpe-py/src/kpe/core/influence.py::aipw_influence`.
#'
#' @return list with `psi` (numeric length n_test),
#'   `policy_action` (integer), `overall_action` (integer).
#' @keywords internal
.aipw_influence <- function(X, A, Y, X_policy, propensity_observed,
                            reward_model, contextual_policy, best_arm) {
  policy_action <- as.integer(contextual_policy$predict(X_policy))
  best_single <- as.integer(best_arm$predict())
  overall_actions <- rep(best_single, length(A))

  m_policy  <- .predict_reward(reward_model, X, policy_action)
  m_overall <- .predict_reward(reward_model, X, overall_actions)
  m_A       <- .predict_reward(reward_model, X, A)

  different <- as.numeric(policy_action != overall_actions)
  indicator <- as.numeric(A == policy_action)  * different -
               as.numeric(A == overall_actions) * different
  residual <- Y - m_A
  psi <- (m_policy - m_overall) + indicator / propensity_observed * residual

  list(
    psi = psi,
    policy_action = policy_action,
    overall_action = overall_actions
  )
}


#' Apply reward_model$predict with (X, A) appended.
#' @keywords internal
.predict_reward <- function(reward_model, X, A) {
  XA <- cbind(X, as.numeric(A))
  preds <- reward_model$predict(XA)
  as.numeric(preds)
}
