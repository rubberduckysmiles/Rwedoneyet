# Generator statistics for the Capability tab.
#
# This is a PROJECTION, not a formula. Every value it returns is copied from a
# field generator_analysis() already computed (which itself only calls
# imr_limits and special_cause_test_1). Nothing is derived, averaged or
# re-scored here, so the page cannot drift from the charts.
#
# g: a generator_analysis() result, or NULL when no log is loaded.
generator_stats <- function(g) {
  if (is.null(g)) return(NULL)

  needed <- c("x", "n", "limits", "flagged")
  missing <- setdiff(needed, names(g))
  if (length(missing) > 0) {
    stop("g must be a generator_analysis() result; missing: ",
         paste(missing, collapse = ", "),
         ". Needed: x, n, limits, flagged.")
  }

  lim <- g$limits
  # A count of flagged tests: integer, and 0 when nothing fired, never NA.
  beyond <- length(g$flagged)

  # in_control can only be TRUE or FALSE when the limits were actually drawn.
  # When imr_limits refused (too few values, a missing value, or a series that
  # does not vary) the honest answer is NA - "cannot say", not "all good".
  assessable <- is.finite(lim$ucl)

  list(
    last = if (g$n > 0) utils::tail(g$x, 1) else NA_real_,
    typical = lim$center,   # the individuals chart center: normal switchover time
    ucl = lim$ucl,          # center + 3 sigma: beyond this a switchover is slow
    beyond = beyond,        # how many tests fell outside the limits
    assessable = assessable,
    in_control = if (assessable) beyond == 0 else NA,
    n = g$n,
    message = lim$message
  )
}
