# Cross-language golden-fixture parity test.
#
# Loads dataset.csv, folds.csv, expected.csv from tests/testthat/golden/.
# dataset.csv and folds.csv are persisted by the Python generator so the R
# side can skip its own RNG/fold construction and target the same
# reference behaviour. When both languages use closed-form OLS + empirical-
# mean-per-arm, the per-shuffle psi_hat and sigma_hat pairs must agree
# to ≤ 1e-8.

TOL <- 1e-8


load_golden <- function() {
  dir <- testthat::test_path("golden")
  list(
    dataset = utils::read.csv(file.path(dir, "dataset.csv")),
    folds = utils::read.csv(file.path(dir, "folds.csv")),
    expected = utils::read.csv(file.path(dir, "expected.csv"))
  )
}


# Mirror of kpe()'s internal pipeline but with the seed-dependent fold
# generation replaced by the ids persisted to folds.csv. Keeps the rest of
# the pipeline (registry resolution, single_split_kpe, aggregate) identical
# to the production path.
run_with_fixed_folds <- function(dataset_df, folds_df, n_folds) {
  X <- as.matrix(dataset_df[, grep("^X", names(dataset_df))])
  A <- as.integer(dataset_df$A)
  Y <- as.numeric(dataset_df$Y)

  inputs <- kpe:::.check_inputs(X, A, Y, propensity = 0.5)

  reward_builder <- kpe:::.resolve_reward("linear", seed = 0L)
  policy_builder <- kpe:::.resolve_policy("linear", seed = 0L)
  best_arm_builder <- kpe:::.resolve_best_arm("simple", seed = 0L)

  shuffles <- list()
  for (s_row in seq_len(nrow(folds_df))) {
    s <- as.integer(folds_df[s_row, "shuffle"])
    fold_ids <- as.integer(
      folds_df[s_row, grep("^sample_", names(folds_df))])
    fold_list <- lapply(seq_len(n_folds) - 1L, function(k) {
      which(fold_ids == k)
    })
    shuffles[[s_row]] <- kpe:::.single_split_kpe(
      inputs,
      reward_builder = reward_builder,
      policy_builder = policy_builder,
      best_arm_builder = best_arm_builder,
      n_folds = n_folds,
      seed = s,
      folds_override = fold_list
    )
  }
  shuffles
}


test_that("R matches kpe-py golden fixture to 1e-8 (linear+simple+linear)", {
  golden <- load_golden()
  expected <- golden$expected
  n_folds <- 6L

  shuffles <- run_with_fixed_folds(golden$dataset, golden$folds, n_folds)

  got_psi <- vapply(shuffles, function(r) r$psi_hat, numeric(1))
  got_sigma <- vapply(shuffles, function(r) r$sigma_hat, numeric(1))
  exp_psi <- expected$psi_hat
  exp_sigma <- expected$sigma_hat

  expect_equal(length(got_psi), length(exp_psi))
  max_psi <- max(abs(got_psi - exp_psi))
  max_sigma <- max(abs(got_sigma - exp_sigma))
  expect_lt(max_psi, TOL,
            label = sprintf("psi_hat diff = %.3e (tol %.1e)", max_psi, TOL))
  expect_lt(max_sigma, TOL,
            label = sprintf("sigma_hat diff = %.3e (tol %.1e)", max_sigma, TOL))
})
