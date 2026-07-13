# Golden-fixture parity for the baselines (train_eval + papd).
#
# Loads the same dataset.csv used by test-golden-parity.R and additionally
# loads:
#   * expected_train_eval.csv / train_eval_order.csv (TrainEval)
#   * expected_papd.csv / folds_papd.csv             (PAPD)
# The order / fold files let R skip its own RNG and target the same
# partitions kpe-py used, so the closed-form OLS + empirical-mean pipeline
# agrees with Python to ≤ 1e-8 per shuffle.

TOL <- 1e-8


load_baseline_goldens <- function() {
  dir <- testthat::test_path("golden")
  list(
    dataset = utils::read.csv(file.path(dir, "dataset.csv")),
    expected_trev = utils::read.csv(file.path(dir, "expected_train_eval.csv")),
    expected_papd = utils::read.csv(file.path(dir, "expected_papd.csv")),
    train_eval_order = utils::read.csv(file.path(dir, "train_eval_order.csv")),
    folds_papd = utils::read.csv(file.path(dir, "folds_papd.csv"))
  )
}


test_that("R train_eval matches kpe-py golden (linear + simple, ≤1e-8)", {
  g <- load_baseline_goldens()
  X <- as.matrix(g$dataset[, grep("^X", names(g$dataset))])
  A <- as.integer(g$dataset$A)
  Y <- as.numeric(g$dataset$Y)
  inputs <- kpe:::.check_inputs(X, A, Y, propensity = 0.5)

  reward_builder <- kpe:::.resolve_reward("linear", seed = 0L)
  policy_builder <- kpe:::.resolve_policy("linear", seed = 0L)
  best_arm_builder <- kpe:::.resolve_best_arm("simple", seed = 0L)

  got_psi <- numeric(nrow(g$expected_trev))
  got_sig <- numeric(nrow(g$expected_trev))
  for (row in seq_len(nrow(g$train_eval_order))) {
    s <- as.integer(g$train_eval_order[row, "shuffle"])
    order0 <- as.integer(g$train_eval_order[row, grep("^order_", names(g$train_eval_order))])
    order1 <- order0 + 1L  # 1-based for R indexing
    r <- kpe:::.single_split_train_eval(
      inputs,
      reward_builder = reward_builder,
      policy_builder = policy_builder,
      best_arm_builder = best_arm_builder,
      seed = s,
      order_override = order1
    )
    got_psi[row] <- r$psi_hat
    got_sig[row] <- r$sigma_hat
  }
  exp_psi <- g$expected_trev$psi_hat
  exp_sig <- g$expected_trev$sigma_hat
  expect_lt(max(abs(got_psi - exp_psi)), TOL)
  expect_lt(max(abs(got_sig - exp_sig)), TOL)
})


test_that("R papd matches kpe-py golden (linear + simple, ≤1e-8)", {
  g <- load_baseline_goldens()
  X <- as.matrix(g$dataset[, grep("^X", names(g$dataset))])
  A <- as.integer(g$dataset$A)
  Y <- as.numeric(g$dataset$Y)
  inputs <- kpe:::.check_inputs(X, A, Y, propensity = 0.5)
  n <- nrow(inputs$X)

  policy_builder <- kpe:::.resolve_policy("linear", seed = 0L)
  best_arm_builder <- kpe:::.resolve_best_arm("simple", seed = 0L)

  got_psi <- numeric(nrow(g$expected_papd))
  got_sig <- numeric(nrow(g$expected_papd))
  for (row in seq_len(nrow(g$folds_papd))) {
    s <- as.integer(g$folds_papd[row, "shuffle"])
    fold_ids <- as.integer(
      g$folds_papd[row, grep("^sample_", names(g$folds_papd))])
    fold_list <- lapply(seq_len(3L) - 1L, function(k) which(fold_ids == k))
    r <- kpe:::.single_split_papd(
      inputs,
      policy_builder = policy_builder,
      best_arm_builder = best_arm_builder,
      n_folds = 3L,
      seed = s,
      folds_override = fold_list
    )
    got_psi[row] <- r$psi_hat
    got_sig[row] <- r$sigma_hat
  }
  exp_psi <- g$expected_papd$psi_hat
  exp_sig <- g$expected_papd$sigma_hat
  expect_lt(max(abs(got_psi - exp_psi)), TOL)
  expect_lt(max(abs(got_sig - exp_sig)), TOL)
})
