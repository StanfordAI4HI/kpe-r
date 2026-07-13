#' Propensity-model builders: estimate p(a | x) for each action.
#'
#' Used only when `kpe(..., is_rct = FALSE)`. For RCT data the known propensity
#' is passed in and these are never fit. Each builder returns a list with
#' `fit(X, A, n_actions)` returning `self` and `predict_proba(X)` returning an
#' (n, n_actions) matrix with columns aligned to actions 0..n_actions-1; absent
#' actions get a small floor probability and rows are renormalized.
#' @keywords internal

#' Map a (n, length(present)) probability block onto a full (n, K) matrix.
#' @keywords internal
.align_proba <- function(raw, present_actions, n_actions, floor = 1e-6) {
  n <- nrow(raw)
  P <- matrix(floor, n, n_actions)
  for (j in seq_along(present_actions)) {
    P[, present_actions[j] + 1L] <- raw[, j]
  }
  P <- pmax(P, floor)
  P / rowSums(P)
}


#' Multinomial logistic propensity via glmnet (cross-validated lambda).
#' @keywords internal
.propensity_logistic <- function(seed = NULL) {
  if (!requireNamespace("glmnet", quietly = TRUE)) {
    stop("propensity_model = \"logistic\" requires the `glmnet` package.")
  }
  function() {
    model <- NULL
    present <- NULL
    n_actions <- NULL
    single <- NULL
    self <- list(
      fit = function(X, A, n_actions) {
        n_actions <<- n_actions
        Xm <- as.matrix(X)
        ua <- sort(unique(A))
        if (length(ua) < 2L) {
          single <<- ua[1]; model <<- NULL; return(invisible(self))
        }
        single <<- NULL
        yf <- droplevels(factor(A, levels = 0:(n_actions - 1L)))
        present <<- as.integer(levels(yf))
        model <<- glmnet::cv.glmnet(Xm, yf, family = "multinomial")
        invisible(self)
      },
      predict_proba = function(X) {
        Xm <- as.matrix(X); nn <- nrow(Xm)
        if (is.null(model)) {
          P <- matrix(1e-6, nn, n_actions); P[, single + 1L] <- 1
          return(P / rowSums(P))
        }
        pr <- stats::predict(model, newx = Xm, s = "lambda.min",
                             type = "response")
        pr <- pr[, , 1L]
        if (is.null(dim(pr))) pr <- matrix(pr, nrow = nn)
        .align_proba(pr, present, n_actions)
      }
    )
    self
  }
}


#' Random-forest propensity via ranger probability forest.
#' @keywords internal
.propensity_forest <- function(seed = NULL, num_trees = 100L,
                               rf_threads = getOption("kpe.rf_threads", 1L)) {
  if (!requireNamespace("ranger", quietly = TRUE)) {
    stop("propensity_model = \"random_forest\" requires the `ranger` package.")
  }
  function() {
    model <- NULL
    present <- NULL
    n_actions <- NULL
    single <- NULL
    self <- list(
      fit = function(X, A, n_actions) {
        n_actions <<- n_actions
        ua <- sort(unique(A))
        if (length(ua) < 2L) {
          single <<- ua[1]; model <<- NULL; return(invisible(self))
        }
        single <<- NULL
        yf <- droplevels(factor(A, levels = 0:(n_actions - 1L)))
        present <<- as.integer(levels(yf))
        df <- .as_named_df(X); df$.a <- yf
        model <<- ranger::ranger(
          .a ~ ., data = df, probability = TRUE, num.trees = num_trees,
          num.threads = rf_threads,
          seed = if (is.null(seed)) NULL else .nonzero_seed(seed)
        )
        invisible(self)
      },
      predict_proba = function(X) {
        nn <- nrow(as.matrix(X))
        if (is.null(model)) {
          P <- matrix(1e-6, nn, n_actions); P[, single + 1L] <- 1
          return(P / rowSums(P))
        }
        pr <- stats::predict(model, data = .as_named_df(X))$predictions
        .align_proba(pr, present, n_actions)
      }
    )
    self
  }
}
