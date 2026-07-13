#' Across-shuffle aggregation: Algorithm 1 variance decomposition + Cauchy.
#'
#' Given S per-shuffle (psi_hat, sigma_hat) pairs,
#'
#'     psi        = mean_s psi_hat
#'     var_total  = mean_s (sigma_hat^2 + (psi_hat - psi)^2)
#'     se         = sqrt(var_total / n)
#'     t_stat     = psi / se
#'     p_value    = one-sided upper-tail p-value under t_{n-1}
#'
#' Per-shuffle one-sided p-values are also produced from a standard-normal
#' approximation and fed into the Cauchy combination test.
#'
#' @keywords internal
.aggregate_shuffles <- function(psi_hats, sigma_hats, n_samples, alpha = 0.05) {
  psi_hats <- as.numeric(psi_hats)
  sigma_hats <- as.numeric(sigma_hats)

  if (all(psi_hats == 0)) {
    psi_mean <- 0
    se <- 0
    t_stat <- 0
    p_value <- 1
    p_per <- rep(1, length(psi_hats))
  } else {
    psi_mean <- mean(psi_hats)
    var_total <- mean(sigma_hats^2 + (psi_hats - psi_mean)^2)
    se <- sqrt(max(var_total, 0) / n_samples)
    df <- max(n_samples - 1L, 1L)
    if (se > 0) {
      t_stat <- psi_mean / se
      p_value <- stats::pt(t_stat, df = df, lower.tail = FALSE)
    } else {
      t_stat <- 0
      p_value <- 1
    }

    t_per <- ifelse(abs(sigma_hats) > 1e-15,
                    sqrt(n_samples) * psi_hats /
                      ifelse(sigma_hats == 0, 1, sigma_hats),
                    0)
    p_per <- 1 - stats::pnorm(t_per)
    p_per[abs(psi_hats) < 1e-15] <- 1
    p_per <- pmin(pmax(p_per, 1e-300), 1 - 1e-15)
  }

  z <- stats::qnorm(1 - alpha / 2)
  ci <- c(psi_mean - z * se, psi_mean + z * se)
  cauchy_p <- if (psi_mean != 0) .cauchy_combination(p_per) else 1

  list(
    psi = psi_mean,
    std_error = se,
    confidence_interval = ci,
    p_value = p_value,
    psi_per_shuffle = psi_hats,
    sigma_per_shuffle = sigma_hats,
    p_value_per_shuffle = p_per,
    cauchy_p_value = cauchy_p
  )
}


#' Cauchy combination test (Liu & Xie, JASA 2020).
#' @keywords internal
.cauchy_combination <- function(p_values) {
  p <- pmin(pmax(p_values, 1e-15), 1 - 1e-15)
  stat <- mean(tan(pi * (0.5 - p)))
  0.5 - atan(stat) / pi
}
