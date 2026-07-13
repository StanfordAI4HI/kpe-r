#' Contextual-policy builders.
#'
#' Each builder returns a list with `fit(X, A, Y, n_actions)` returning
#' `self` and `predict(X)` returning an integer vector of actions.
#' @keywords internal
.policy_linear <- function(seed = NULL, alpha = 0) {
  function() {
    models <- NULL
    n_actions <- NULL
    d <- NULL
    self <- list(
      fit = function(X, A, Y, n_actions) {
        X2 <- if (is.matrix(X)) X else as.matrix(X)
        models <<- vector("list", n_actions)
        n_actions <<- n_actions
        d <<- ncol(X2)
        for (k in seq_len(n_actions) - 1L) {
          mask <- A == k
          if (sum(mask) == 0L) {
            models[[k + 1L]] <<- list(coef = rep(0, d + 1L),
                                      const = -Inf)
          } else {
            Xd <- cbind(1, X2[mask, , drop = FALSE])
            if (alpha > 0) {
              # Closed-form ridge: (X'X + alpha*I)^-1 X'y
              p <- ncol(Xd)
              reg <- alpha * diag(p)
              reg[1, 1] <- 0  # don't penalize the intercept
              beta <- solve(crossprod(Xd) + reg, crossprod(Xd, Y[mask]))
            } else {
              beta <- .ols(Xd, Y[mask])
            }
            models[[k + 1L]] <<- list(coef = as.numeric(beta), const = NA_real_)
          }
        }
        self
      },
      predict = function(X) {
        X2 <- if (is.matrix(X)) X else as.matrix(X)
        scores <- sapply(models, function(m) {
          if (!is.na(m$const) && is.infinite(m$const)) {
            return(rep(m$const, nrow(X2)))
          }
          as.numeric(cbind(1, X2) %*% m$coef)
        })
        if (!is.matrix(scores)) scores <- matrix(scores, nrow = nrow(X2))
        as.integer(max.col(scores, ties.method = "first") - 1L)
      }
    )
    self
  }
}


.policy_forest <- function(seed = NULL, num_trees = 500L) {
  if (!requireNamespace("grf", quietly = TRUE)) {
    stop("contextual_policy = \"policy_forest\" requires the `grf` package.")
  }
  function() {
    forest <- NULL
    self <- list(
      fit = function(X, A, Y, n_actions) {
        if (n_actions != 2L) {
          stop("contextual_policy = \"policy_forest\" is binary-treatment ",
               "only (grf::causal_forest). For multi-arm data use ",
               "contextual_policy = \"policy_tree\".")
        }
        X2 <- if (is.matrix(X)) X else as.matrix(X)
        forest <<- grf::causal_forest(
          X = X2, Y = Y, W = as.numeric(A),
          num.trees = num_trees,
          seed = .nonzero_seed(if (is.null(seed)) 1L else seed)
        )
        self
      },
      predict = function(X) {
        X2 <- if (is.matrix(X)) X else as.matrix(X)
        tau_hat <- stats::predict(forest, newdata = X2)$predictions
        # tau_hat > 0 => treated arm (1) is better. Binary-only by design.
        as.integer(tau_hat > 0)
      }
    )
    self
  }
}


.policy_tree <- function(seed = NULL, depth = 2L, min_node_size = 5L,
                         cv = 2L, num_trees = 100L,
                         rf_threads = getOption("kpe.rf_threads", 1L)) {
  if (!requireNamespace("policytree", quietly = TRUE)) {
    stop("contextual_policy = \"policy_tree\" requires the `policytree` package.")
  }
  function() {
    tree <- NULL
    self <- list(
      fit = function(X, A, Y, n_actions) {
        X2 <- if (is.matrix(X)) X else as.matrix(X)
        # Doubly-robust score matrix for policytree::policy_tree, built to
        # mirror econml's DRPolicyTree(model_regression = "auto",
        # model_propensity = constant-empirical) used by kpe-py and the
        # original research code (dr_econml_2):
        #
        #   Gamma_{i,a} = mu_hat_a(X_i)
        #                 + 1{A_i = a} / p_hat(a) * (Y_i - mu_hat_a(X_i)),
        #
        # where mu_hat_a(.) is an X-DEPENDENT outcome regression obtained by
        # cross-fitting a single joint model mu_hat(X, onehot(A)) -> Y (the
        # treatment one-hot encoded with the baseline arm dropped, matching
        # econml's hstack([X, T])), and selecting between a CV-Lasso and a
        # random forest by cross-validated MSE ("auto" = linear vs forest).
        # p_hat(a) is the constant empirical action marginal.
        n <- nrow(X2)
        probs <- tabulate(A + 1L, nbins = n_actions) / n
        probs[probs < 1e-6] <- 1e-6

        mu_oof <- .dr_crossfit_mu(
          X2, A, Y, n_actions,
          cv = cv, seed = seed, num_trees = num_trees, rf_threads = rf_threads
        )

        Gamma <- mu_oof
        realized <- cbind(seq_len(n), A + 1L)
        Gamma[realized] <- mu_oof[realized] +
          (Y - mu_oof[realized]) / probs[A + 1L]

        tree <<- policytree::policy_tree(
          X = X2, Gamma = Gamma, depth = depth,
          min.node.size = min_node_size, verbose = FALSE
        )
        self
      },
      predict = function(X) {
        X2 <- if (is.matrix(X)) X else as.matrix(X)
        as.integer(stats::predict(tree, X2)) - 1L
      }
    )
    self
  }
}


#' One-hot encode an integer action vector with the baseline arm (0) dropped.
#' Returns an (length(a) x (n_actions - 1)) numeric matrix, mirroring econml's
#' treatment encoding (baseline category omitted). For binary treatments this
#' is a single column 1{a == 1}.
#' @keywords internal
.onehot_drop_baseline <- function(a, n_actions) {
  if (n_actions <= 1L) return(matrix(0, length(a), 0L))
  m <- matrix(0, length(a), n_actions - 1L)
  for (k in seq_len(n_actions - 1L)) m[, k] <- as.numeric(a == k)
  m
}


#' Deterministic CV fold ids (no global-RNG side effects). Row i is assigned to
#' fold (i mod cv), giving cv roughly-equal contiguous-by-stride folds.
#' @keywords internal
.cv_fold_ids <- function(n, cv) {
  (seq_len(n) - 1L) %% cv + 1L
}


#' Cross-fitted, X-dependent per-arm outcome regression mu_hat_a(X).
#'
#' Fits a single joint regression mu_hat(X, onehot(A)) -> Y with `cv`-fold
#' cross-fitting and returns the out-of-fold prediction matrix mu_oof of shape
#' (n, n_actions): mu_oof[i, a + 1] = mu_hat_a(X_i) evaluated by setting the
#' treatment one-hot to arm a. The regression family (CV-Lasso vs random
#' forest) is chosen once on the full fold by cross-validated MSE, replicating
#' econml's model_regression = "auto" (ListSelector(["linear", "forest"])).
#' @keywords internal
.dr_crossfit_mu <- function(X, A, Y, n_actions, cv = 2L, seed = NULL,
                            num_trees = 100L, rf_threads = 1L) {
  n <- nrow(X)
  cv <- max(2L, as.integer(cv))
  fold_id <- .cv_fold_ids(n, cv)

  chosen <- .select_reg_family(
    X, A, Y, n_actions, cv = cv, seed = seed,
    num_trees = num_trees, rf_threads = rf_threads
  )

  mu_oof <- matrix(0, n, n_actions)
  for (f in seq_len(cv)) {
    test <- which(fold_id == f)
    train <- which(fold_id != f)
    if (length(train) == 0L || length(test) == 0L) next
    feat_tr <- cbind(X[train, , drop = FALSE],
                     .onehot_drop_baseline(A[train], n_actions))
    fit <- .fit_reg_family(chosen, feat_tr, Y[train], seed = seed,
                           num_trees = num_trees, rf_threads = rf_threads)
    for (a in seq_len(n_actions) - 1L) {
      feat_te <- cbind(X[test, , drop = FALSE],
                       .onehot_drop_baseline(rep.int(a, length(test)), n_actions))
      mu_oof[test, a + 1L] <- .predict_reg_family(chosen, fit, feat_te)
    }
  }
  mu_oof
}


#' Choose "linear" (CV-Lasso) vs "forest" (random forest) by cross-validated
#' MSE on the joint regression task Y ~ [X, onehot(A)]. Returns "linear" or
#' "forest". Mirrors econml's ListSelector picking the higher-scoring of the
#' two "auto" candidates.
#' @keywords internal
.select_reg_family <- function(X, A, Y, n_actions, cv = 2L, seed = NULL,
                               num_trees = 100L, rf_threads = 1L) {
  feat <- cbind(X, .onehot_drop_baseline(A, n_actions))
  # glmnet needs >= 2 features; fall back to forest if too few columns.
  have_glmnet <- requireNamespace("glmnet", quietly = TRUE) && ncol(feat) >= 2L
  have_ranger <- requireNamespace("ranger", quietly = TRUE)
  if (!have_glmnet) return("forest")
  if (!have_ranger) return("linear")

  n <- nrow(feat)
  fold_id <- .cv_fold_ids(n, cv)
  sse <- c(linear = 0, forest = 0)
  for (f in seq_len(cv)) {
    test <- which(fold_id == f); train <- which(fold_id != f)
    if (length(train) == 0L || length(test) == 0L) next
    ytr <- Y[train]; yte <- Y[test]
    ftr <- feat[train, , drop = FALSE]; fte <- feat[test, , drop = FALSE]
    fit_l <- .fit_reg_family("linear", ftr, ytr, seed = seed,
                             num_trees = num_trees, rf_threads = rf_threads)
    fit_f <- .fit_reg_family("forest", ftr, ytr, seed = seed,
                             num_trees = num_trees, rf_threads = rf_threads)
    sse["linear"] <- sse["linear"] +
      sum((yte - .predict_reg_family("linear", fit_l, fte))^2)
    sse["forest"] <- sse["forest"] +
      sum((yte - .predict_reg_family("forest", fit_f, fte))^2)
  }
  if (sse["forest"] <= sse["linear"]) "forest" else "linear"
}


#' Fit one regression family. `family` is "linear" (cv.glmnet LASSO, lambda
#' chosen by internal CV) or "forest" (ranger random forest). Feature matrix
#' already includes the treatment one-hot columns.
#' @keywords internal
.fit_reg_family <- function(family, feat, y, seed = NULL,
                            num_trees = 100L, rf_threads = 1L) {
  if (family == "linear") {
    Xmat <- as.matrix(feat)
    nfolds <- max(3L, min(10L, nrow(Xmat)))
    foldid <- .cv_fold_ids(nrow(Xmat), nfolds)
    model <- glmnet::cv.glmnet(Xmat, y, alpha = 1, foldid = foldid)
    list(family = "linear", model = model)
  } else {
    df <- .as_named_df(feat)
    df$.y <- y
    model <- ranger::ranger(
      .y ~ ., data = df, num.trees = num_trees,
      num.threads = rf_threads,
      seed = if (is.null(seed)) NULL else .nonzero_seed(seed)
    )
    list(family = "forest", model = model)
  }
}


#' Predict from a fitted regression family on a new feature matrix.
#' @keywords internal
.predict_reg_family <- function(family, fit, feat) {
  if (family == "linear") {
    as.numeric(stats::predict(fit$model, newx = as.matrix(feat),
                              s = "lambda.min"))
  } else {
    as.numeric(stats::predict(fit$model, data = .as_named_df(feat))$predictions)
  }
}


#' Coerce a feature matrix to a data frame with deterministic column names
#' (f1, f2, ...), so ranger fit/predict align regardless of incoming colnames.
#' @keywords internal
.as_named_df <- function(feat) {
  m <- as.matrix(feat)
  colnames(m) <- paste0("f", seq_len(ncol(m)))
  as.data.frame(m)
}
