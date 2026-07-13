# End-to-end tests for the baselines (train_eval + papd) on a shared
# signal/null synthetic.

make_signal <- function(seed = 1L, n = 200L) {
  set.seed(seed)
  X <- matrix(runif(n * 2, -1, 1), ncol = 2)
  A <- rbinom(n, 1, 0.5)
  Y <- ifelse(X[, 1] >= 0, A, 0.5 * (1 - A)) + rnorm(n, sd = 0.3)
  list(X = X, A = A, Y = Y)
}

make_null <- function(seed = 2L, n = 200L) {
  set.seed(seed)
  X <- matrix(runif(n * 2, -1, 1), ncol = 2)
  A <- rbinom(n, 1, 0.5)
  Y <- A + rnorm(n, sd = 0.3)  # always-treat optimal; no personalization value
  list(X = X, A = A, Y = Y)
}


test_that("train_eval returns a kpe object with NaN policy_stability", {
  d <- make_signal()
  fit <- kpe::train_eval(d$X, d$A, d$Y, propensity = 0.5,
                         n_shuffles = 4, contextual_policy = "linear",
                         best_arm = "simple", reward_model = "linear",
                         seed = 0)
  expect_s3_class(fit, "kpe")
  expect_equal(fit$method, "train_eval")
  expect_equal(fit$n_folds, 2L)
  expect_true(is.nan(fit$policy_stability))
})


test_that("train_eval detects a positive personalization effect", {
  d <- make_signal(n = 400L)
  fit <- kpe::train_eval(d$X, d$A, d$Y, propensity = 0.5,
                         n_shuffles = 8, contextual_policy = "linear",
                         best_arm = "simple", reward_model = "linear",
                         seed = 0)
  expect_gt(fit$psi, 0)
  expect_lt(fit$p_value, 0.1)
})


test_that("train_eval does not reject under null (constant effect)", {
  d <- make_null(n = 400L)
  fit <- kpe::train_eval(d$X, d$A, d$Y, propensity = 0.5,
                         n_shuffles = 8, contextual_policy = "linear",
                         best_arm = "simple", reward_model = "linear",
                         seed = 0)
  expect_gte(fit$p_value, 0.05)
})


test_that("papd returns a kpe object with n_folds fixed at 3", {
  d <- make_signal()
  fit <- kpe::papd(d$X, d$A, d$Y, propensity = 0.5,
                   n_shuffles = 4, contextual_policy = "linear",
                   best_arm = "simple", reward_model = "linear",
                   seed = 0, n_folds = 99)  # 99 should be ignored
  expect_s3_class(fit, "kpe")
  expect_equal(fit$method, "papd")
  expect_equal(fit$n_folds, 3L)
})


test_that("papd detects signal / null correctly", {
  sig <- kpe::papd(make_signal(n = 400L)$X, make_signal(n = 400L)$A,
                   make_signal(n = 400L)$Y, propensity = 0.5,
                   n_shuffles = 8, contextual_policy = "linear",
                   best_arm = "simple", seed = 0)
  null <- kpe::papd(make_null(n = 400L)$X, make_null(n = 400L)$A,
                    make_null(n = 400L)$Y, propensity = 0.5,
                    n_shuffles = 8, contextual_policy = "linear",
                    best_arm = "simple", seed = 0)
  expect_gt(sig$psi, 0)
  expect_lt(sig$p_value, 0.1)
  expect_gte(null$p_value, 0.05)
})


test_that("BYO reward_model via list(fit, predict) runs end-to-end", {
  d <- make_signal(n = 300L)
  # Closure-based BYO learner — per-fit mean of Y. Not statistically
  # useful, but exercises the list(fit, predict) resolver path.
  byo <- local({
    mu <- NULL
    list(
      fit = function(X, y) { mu <<- mean(y); invisible(NULL) },
      predict = function(X) rep(mu, nrow(as.matrix(X)))
    )
  })
  # The builder returns the same list for every fold; that's the documented
  # BYO contract in .resolve_reward.
  fit <- kpe::kpe(d$X, d$A, d$Y, propensity = 0.5,
                  n_shuffles = 3, n_folds = 6,
                  reward_model = byo,
                  contextual_policy = "linear",
                  best_arm = "simple",
                  seed = 0)
  expect_s3_class(fit, "kpe")
  expect_true(is.finite(fit$psi))
})
