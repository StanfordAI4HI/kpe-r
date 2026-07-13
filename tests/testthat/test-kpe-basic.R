test_that("kpe() returns a kpe object with expected fields", {
  set.seed(1)
  n <- 200
  X <- matrix(runif(n * 2, -1, 1), ncol = 2)
  A <- rbinom(n, 1, 0.5)
  Y <- ifelse(X[, 1] >= 0, A, 0.5 * (1 - A)) + rnorm(n, sd = 0.3)

  fit <- kpe(X, A, Y, propensity = 0.5,
             n_shuffles = 4, n_folds = 6,
             contextual_policy = "linear",
             best_arm = "simple",
             reward_model = "linear",
             seed = 0)
  expect_s3_class(fit, "kpe")
  expect_equal(fit$method, "kpe")
  expect_equal(length(fit$psi_per_shuffle), 4L)
  expect_equal(length(fit$sigma_per_shuffle), 4L)
  expect_equal(length(fit$confidence_interval), 2L)
  expect_true(is.finite(fit$psi))
})


test_that("kpe() detects a positive personalization effect", {
  set.seed(2)
  n <- 400
  X <- matrix(runif(n * 2, -1, 1), ncol = 2)
  A <- rbinom(n, 1, 0.5)
  Y <- ifelse(X[, 1] >= 0, A, 0.5 * (1 - A)) + rnorm(n, sd = 0.3)

  fit <- kpe(X, A, Y, propensity = 0.5,
             n_shuffles = 8, n_folds = 6,
             contextual_policy = "linear",
             best_arm = "simple",
             reward_model = "linear",
             seed = 0)
  expect_gt(fit$psi, 0)
  expect_lt(fit$p_value, 0.1)
})


test_that("kpe() does not reject under constant treatment effect", {
  set.seed(3)
  n <- 400
  X <- matrix(runif(n * 2, -1, 1), ncol = 2)
  A <- rbinom(n, 1, 0.5)
  Y <- A + rnorm(n, sd = 0.3)  # always-treat optimal; no personalization value

  fit <- kpe(X, A, Y, propensity = 0.5,
             n_shuffles = 8, n_folds = 6,
             contextual_policy = "linear",
             best_arm = "simple",
             reward_model = "linear",
             seed = 0)
  expect_gte(fit$p_value, 0.05)
})


test_that("input validation rejects bad shapes and zero propensity", {
  X <- matrix(0, nrow = 10, ncol = 2)
  A <- rep(0L, 10); A[1:5] <- 1L  # two actions
  Y <- rep(0.0, 10)

  expect_error(kpe(X, A, Y[1:5], 0.5),
               regexp = "Y must have length")
  expect_error(kpe(X, A, Y, 0),
               regexp = "positive and finite")

  A_bad <- rep(-1L, 10)
  expect_error(kpe(X, A_bad, Y, 0.5),
               regexp = "non-negative integers")
})


test_that("S3 methods run without error", {
  set.seed(4)
  n <- 150
  X <- matrix(runif(n * 2, -1, 1), ncol = 2)
  A <- rbinom(n, 1, 0.5)
  Y <- ifelse(X[, 1] >= 0, A, 0.5 * (1 - A)) + rnorm(n, sd = 0.3)

  fit <- kpe(X, A, Y, propensity = 0.5,
             n_shuffles = 3, n_folds = 6,
             contextual_policy = "linear",
             best_arm = "simple",
             reward_model = "linear",
             seed = 0)
  expect_output(print(fit), "K-Fold Personalization Estimator")
  expect_output(print(summary(fit)), "Summary of K-Fold")
  ci <- confint(fit)
  expect_true(is.matrix(ci))
  expect_equal(coef(fit), c(psi = fit$psi))
})
