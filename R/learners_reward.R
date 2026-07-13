#' Reward-model builders.
#'
#' Each builder returns a list with a `fit(X, y)` method returning `self` and
#' a `predict(X)` method returning a numeric vector. The cross-fit loop calls
#' the builder once per fold to avoid state leakage between folds.
#' @keywords internal
.reward_random_forest <- function(seed = NULL, num_trees = 100L,
                                  rf_threads = getOption("kpe.rf_threads", 1L)) {
  if (!requireNamespace("ranger", quietly = TRUE)) {
    stop("reward_model = \"random_forest\" requires the `ranger` package.")
  }
  function() {
    model <- NULL
    self <- list(
      fit = function(X, y) {
        df <- data.frame(X, y = y)
        # num.threads = 1 (default) makes ranger's RNG reproducible: with the
        # multi-threaded default the reward forest is nondeterministic and
        # biased, which threw off the AIPW plug-in (mirrors the propensity
        # forest, which already pins threads).
        model <<- ranger::ranger(
          y ~ ., data = df, num.trees = num_trees, num.threads = rf_threads,
          seed = if (is.null(seed)) NULL else .nonzero_seed(seed))
        self
      },
      predict = function(X) {
        as.numeric(stats::predict(model, data = data.frame(X),
                                  num.threads = rf_threads)$predictions)
      }
    )
    self
  }
}

.reward_linear <- function(seed = NULL) {
  function() {
    coefs <- NULL
    self <- list(
      fit = function(X, y) {
        Xd <- cbind(1, X)
        coefs <<- as.numeric(.ols(Xd, y))
        self
      },
      predict = function(X) {
        as.numeric(cbind(1, X) %*% coefs)
      }
    )
    self
  }
}


.reward_ridge <- function(seed = NULL, alpha = 1.0) {
  function() {
    coefs <- NULL
    self <- list(
      fit = function(X, y) {
        Xd <- cbind(1, X)
        coefs <<- as.numeric(.ridge_closed_form(Xd, y, lambda = alpha))
        self
      },
      predict = function(X) {
        as.numeric(cbind(1, X) %*% coefs)
      }
    )
    self
  }
}


.reward_lasso <- function(seed = NULL, alpha = 0.1) {
  if (!requireNamespace("glmnet", quietly = TRUE)) {
    stop("reward_model = \"lasso\" requires the `glmnet` package.")
  }
  function() {
    model <- NULL
    self <- list(
      fit = function(X, y) {
        Xmat <- as.matrix(X)
        # glmnet with alpha=1 is lasso; fit at a single lambda = alpha.
        model <<- glmnet::glmnet(Xmat, y, alpha = 1,
                                 lambda = alpha, standardize = TRUE)
        self
      },
      predict = function(X) {
        as.numeric(stats::predict(model, newx = as.matrix(X)))
      }
    )
    self
  }
}


#' Closed-form ridge: (X'X + lambda * I)^-1 X'y with no penalty on intercept.
#' X must already include a leading intercept column.
#' @keywords internal
.ridge_closed_form <- function(X, y, lambda) {
  p <- ncol(X)
  reg <- lambda * diag(p)
  reg[1, 1] <- 0
  solve(crossprod(X) + reg, crossprod(X, y))
}

#' Fast closed-form OLS with a minimum-norm fallback for rank-deficient X.
#' @keywords internal
.ols <- function(X, y) {
  qr_x <- qr(X)
  if (qr_x$rank < ncol(X)) {
    # Pseudo-inverse for rank-deficient X
    svd_x <- svd(X)
    tol <- max(dim(X)) * max(svd_x$d) * .Machine$double.eps
    d_inv <- ifelse(svd_x$d > tol, 1 / svd_x$d, 0)
    return(svd_x$v %*% (d_inv * crossprod(svd_x$u, y)))
  }
  qr.coef(qr_x, y)
}
