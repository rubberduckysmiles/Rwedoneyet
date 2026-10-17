# Individuals and moving-range (I-MR) limits, for one measurement per time, e.g. generator transfer seconds.
# Moving range = absolute difference between neighbouring values.
# sigma_short = mean moving range / d2, with d2 computed for n = 2.

imr_limits <- function(x) {
  empty <- function(message) {
    list(
      center = NA_real_, lcl = NA_real_, ucl = NA_real_,
      mr_bar = NA_real_, mr_center = NA_real_, mr_lcl = NA_real_, mr_ucl = NA_real_,
      sigma_short = NA_real_, d2 = NA_real_, d3 = NA_real_,
      message = message
    )
  }

  if (length(x) < 2) {
    return(empty("need at least 2 values for a moving range"))
  }
  if (anyNA(x)) {
    return(empty("a value is missing, so the limits are undefined"))
  }
  moving_range <- abs(diff(x))
  mr_bar <- mean(moving_range)
  if (mr_bar == 0) {
    return(empty("the values do not vary (mean moving range is 0), so the limits are undefined"))
  }

  rc <- range_constants(2)
  center <- mean(x)
  sigma_short <- mr_bar / rc$d2

  list(
    center = center,
    lcl = center - 3 * sigma_short,
    ucl = center + 3 * sigma_short,
    mr_bar = mr_bar,
    mr_center = mr_bar,
    mr_lcl = max(0, ((rc$d2 - 3 * rc$d3) / rc$d2) * mr_bar),
    mr_ucl = ((rc$d2 + 3 * rc$d3) / rc$d2) * mr_bar,
    sigma_short = sigma_short,
    d2 = rc$d2,
    d3 = rc$d3,
    message = ""
  )
}
