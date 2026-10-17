# d2 and d3 for subgroups of n readings, computed rather than looked up.
#
# W is the range (largest minus smallest) of n standard normal values.
#   d2 = E[W]            the mean of W
#   d3 = sd(W)           the standard deviation of W
# stats::ptukey(q, nmeans = n, df = Inf) is the distribution function F(w) of W.
# W is never negative, so
#   E[W]   = integral from 0 to Inf of (1 - F(w)) dw
#   E[W^2] = integral from 0 to Inf of 2 * w * (1 - F(w)) dw
#   d3     = sqrt(E[W^2] - d2^2)

range_constants <- function(n) {
  if (length(n) != 1 || !is.numeric(n) || is.na(n) || n != round(n) || n < 2) {
    stop("n must be a single whole number of at least 2 (a range needs two readings)")
  }

  upper_tail <- function(w) 1 - stats::ptukey(w, nmeans = n, df = Inf)

  d2 <- stats::integrate(function(w) upper_tail(w), lower = 0, upper = Inf,
                         rel.tol = 1e-10, subdivisions = 1000L)$value
  mean_square <- stats::integrate(function(w) 2 * w * upper_tail(w), lower = 0, upper = Inf,
                                  rel.tol = 1e-10, subdivisions = 1000L)$value
  d3 <- sqrt(mean_square - d2^2)

  list(d2 = d2, d3 = d3)
}
