# Unit tests for the stability metrics in R/stability.R.
#
# .prediction_stability is the paper's Table S1 *policy* stability
# (per-sample all-shuffles-agree fraction). .best_arm_stability is the paper's
# Table S1 *best-arm* stability (modal-best-arm share across shuffles). The
# two apply to different action matrices and must not be interchanged.

# ----- .prediction_stability (policy) ----------------------------------------

test_that("prediction_stability returns 1 when all shuffles agree", {
  arr <- matrix(3L, nrow = 10, ncol = 50)
  expect_equal(.prediction_stability(arr), 1)
})

test_that("prediction_stability returns 0.5 when half the samples disagree", {
  arr <- matrix(0L, nrow = 5, ncol = 100)
  arr[1, 1:50] <- 1L
  expect_equal(.prediction_stability(arr), 0.5)
})

test_that("prediction_stability rejects non-matrix input", {
  expect_error(.prediction_stability(c(1L, 2L, 3L)),
               "expects a matrix")
})


# ----- .best_arm_stability (Table S1) ----------------------------------------

test_that("best_arm_stability returns 1 when every shuffle picks the same arm", {
  arr <- matrix(3L, nrow = 20, ncol = 1000)
  expect_equal(.best_arm_stability(arr), 1)
})

test_that("best_arm_stability matches Education-style modal share", {
  # 100 shuffles, modal best-arm picked in 26% of them.
  counts <- c(`0` = 18, `1` = 24, `2` = 14, `3` = 26, `4` = 10, `5` = 8)
  rows <- vector("list", sum(counts))
  i <- 1L
  for (arm_label in names(counts)) {
    arm <- as.integer(arm_label)
    for (rep in seq_len(counts[[arm_label]])) {
      rows[[i]] <- rep(arm, 500L)
      i <- i + 1L
    }
  }
  arr <- do.call(rbind, rows)
  expect_equal(dim(arr), c(sum(counts), 500))
  expect_equal(.best_arm_stability(arr), 0.26)
})

test_that("best_arm_stability returns 1/K for an even K-way split", {
  rows <- list()
  for (arm in 0:5) for (rep in 1:10) rows[[length(rows) + 1L]] <- rep(arm, 20L)
  arr <- do.call(rbind, rows)
  expect_equal(.best_arm_stability(arr), 1 / 6, tolerance = 1e-12)
})

test_that("best_arm_stability defensively reduces non-constant rows by mode", {
  # Per-row modes: [0, 2, 0]. Modal share = 2/3.
  arr <- rbind(
    c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 1L, 1L, 1L),
    c(2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L),
    c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L)
  )
  expect_equal(.best_arm_stability(arr), 2 / 3, tolerance = 1e-12)
})

test_that("best_arm_stability treats a 1-D vector as one shuffle of best-arms", {
  v <- c(3L, 3L, 3L, 1L, 1L, 0L, 0L, 0L, 0L, 0L)
  expect_equal(.best_arm_stability(v), 0.5)
})

test_that("best_arm_stability returns 1 for an empty matrix", {
  expect_equal(.best_arm_stability(matrix(integer(0), nrow = 0L, ncol = 10L)), 1)
})
