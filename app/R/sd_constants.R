# c4, B5 and B6 for subgroups of n readings, computed rather than looked up.
#
# s is the sample standard deviation of n standard normal values.
#   E[s]  = c4 * 1          so c4 = E[s] when sigma = 1
#   sd(s) = sqrt(1 - c4^2)  in the same units as sigma
#
# c4 comes from the gamma distribution: (n-1)*s^2/sigma^2 is chi-squared with
# n-1 degrees of freedom, so E[s^2] = sigma^2 and
#   E[s] = sigma * sqrt(2/(n-1)) * Gamma(n/2) / Gamma((n-1)/2).
# Setting sigma = 1 gives c4. Written with lgamma so large n cannot overflow.
#
# With E[s] = c4*sigma and sd(s) = sigma*sqrt(1-c4^2), the 3-sigma lines for s are
#   c4*sigma +/- 3*sigma*sqrt(1-c4^2) = B5*sigma and B6*sigma
# with B5 = c4 - 3*sqrt(1-c4^2) and B6 = c4 + 3*sqrt(1-c4^2).
# B5 is held at 0 when it would be negative, because s cannot be negative.

sd_constants <- function(n) {
  if (length(n) != 1 || !is.numeric(n) || is.na(n) || n != round(n) || n < 2) {
    stop("n must be a single whole number of at least 2 (a standard deviation needs two readings)")
  }

  c4 <- sqrt(2 / (n - 1)) * exp(lgamma(n / 2) - lgamma((n - 1) / 2))
  spread <- sqrt(1 - c4^2)

  list(c4 = c4, B5 = max(0, c4 - 3 * spread), B6 = c4 + 3 * spread)
}
