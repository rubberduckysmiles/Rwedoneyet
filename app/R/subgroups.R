# Subgroups, the two sigmas, and lag-1 autocorrelation.
# Sample variance and sample sd divide by n - 1, like R's var() and sd().
#
# A value that cannot be computed is NA with an attribute called "message" saying why.
# Read it with attr(x, "message"). It is never Inf and never a made-up number.

na_with_message <- function(message) {
  structure(NA_real_, message = message)
}

# Split x (readings in time order) into consecutive groups of n and summarise each group.
# A short last group is kept, with its real n_obs. A group with fewer than 2 readings has no
# variance: variance and sd are NA and the data frame carries a "message" attribute.
subgroup_stats <- function(x, n = 4) {
  if (length(n) != 1 || !is.numeric(n) || is.na(n) || n != round(n) || n < 1) {
    stop("n must be a single whole number of at least 1")
  }
  x <- as.numeric(x)
  count <- length(x)
  n_groups <- ceiling(count / n)
  group_id <- if (count > 0) rep(seq_len(n_groups), each = n, length.out = count) else integer(0)

  out <- data.frame(
    subgroup = seq_len(n_groups),
    mean = NA_real_,
    variance = NA_real_,
    sd = NA_real_,
    range = NA_real_,
    n_obs = 0L
  )
  for (g in seq_len(n_groups)) {
    xs <- x[group_id == g]
    out$n_obs[g] <- length(xs)
    out$mean[g] <- mean(xs)
    out$range[g] <- if (anyNA(xs)) NA_real_ else max(xs) - min(xs)
    if (length(xs) >= 2) {
      out$variance[g] <- stats::var(xs)
      out$sd[g] <- stats::sd(xs)
    }
  }

  message <- ""
  if (any(out$n_obs < 2)) {
    message <- "variance is undefined for a subgroup with fewer than 2 readings"
  }
  attr(out, "message") <- message
  out
}

# sigma_short = square root of the mean within-subgroup sample variance.
sigma_short_from_variances <- function(variances) {
  if (length(variances) == 0 || anyNA(variances)) {
    return(na_with_message("a subgroup variance is missing, so sigma_short is undefined"))
  }
  sqrt(mean(variances))
}

# sigma_overall = sample standard deviation of every reading.
sigma_overall <- function(x) {
  stats::sd(x)
}

# Correlation of each reading with the next one.
lag1_autocorrelation <- function(x) {
  if (length(x) < 3) {
    return(na_with_message("lag-1 autocorrelation needs at least 3 readings"))
  }
  if (anyNA(x)) {
    return(na_with_message("a reading is missing, so lag-1 autocorrelation is undefined"))
  }
  if (stats::sd(x) == 0) {
    return(na_with_message("readings do not vary, so lag-1 autocorrelation is undefined"))
  }
  stats::cor(x[-length(x)], x[-1])
}
