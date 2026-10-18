# Control limits and capability indices.
# sigma_short is the square root of the mean within-subgroup sample variance (see subgroups.R).

# X-bar chart limits. se is the standard error of a subgroup mean.
# zone1, zone2, zone3 are the distances from the center to the 1, 2 and 3 sigma lines.
# If sigma_short is 0 the limits sit on the center. That is allowed.
xbar_limits <- function(center, sigma_short, n) {
  se <- sigma_short / sqrt(n)
  list(
    center = center,
    se = se,
    lcl = center - 3 * se,
    ucl = center + 3 * se,
    zone1 = se,
    zone2 = 2 * se,
    zone3 = 3 * se
  )
}

# Range chart limits. The lower limit is held at 0 because a range cannot be negative.
range_chart_limits <- function(sigma_short, n) {
  rc <- range_constants(n)
  list(
    center = rc$d2 * sigma_short,
    lcl = max(0, (rc$d2 - 3 * rc$d3) * sigma_short),
    ucl = (rc$d2 + 3 * rc$d3) * sigma_short,
    d2 = rc$d2,
    d3 = rc$d3
  )
}

# Standard deviation (s) chart limits. The center is c4*sigma_short because
# E[s] = c4*sigma, and the lines are B5*sigma_short and B6*sigma_short.
# The lower limit is held at 0 because a standard deviation cannot be negative.
sd_chart_limits <- function(sigma_short, n) {
  sc <- sd_constants(n)
  list(
    center = sc$c4 * sigma_short,
    lcl = max(0, sc$B5 * sigma_short),
    ucl = sc$B6 * sigma_short,
    c4 = sc$c4,
    B5 = sc$B5,
    B6 = sc$B6
  )
}

# Cpk uses sigma_short. Ppk uses sigma_overall. gap = Cpk - Ppk.
# When a sigma is 0 (or missing) its index is NA, and so is the gap. Never Inf.
capability_indices <- function(mean, sigma_short, sigma_overall, lsl = 1, usl = 6) {
  if (isTRUE(sigma_short < 0) || isTRUE(sigma_overall < 0)) {
    stop("sigma cannot be negative")
  }
  numerator <- min(usl - mean, mean - lsl)

  short_ok <- isTRUE(sigma_short > 0)
  overall_ok <- isTRUE(sigma_overall > 0)

  cpk <- if (short_ok) numerator / (3 * sigma_short) else NA_real_
  ppk <- if (overall_ok) numerator / (3 * sigma_overall) else NA_real_

  if (short_ok && overall_ok) {
    gap <- cpk - ppk
    message <- ""
  } else {
    gap <- NA_real_
    zero <- isTRUE(sigma_short == 0) || isTRUE(sigma_overall == 0)
    message <- if (zero) "sigma is 0; Cpk and Ppk are undefined" else "sigma is missing; Cpk and Ppk are undefined"
  }

  list(cpk = cpk, ppk = ppk, gap = gap, message = message)
}
