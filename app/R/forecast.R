# Forecast and rolling capability.

# A straight line through the subgroup means gives the hours until it reaches lsl or usl.
# subgroup_means: the post-baseline hourly means, in time order (the caller drops the baseline).
# hours is 0 if the line is already outside the spec, Inf (message "no crossing") if it never
# crosses, NA (with a message) if there are fewer than 3 means.
hours_to_spec <- function(subgroup_means, lsl = 1, usl = 6) {
  n <- length(subgroup_means)
  hour <- seq_len(n) - 1
  ok <- !is.na(subgroup_means)
  if (sum(ok) < 3) {
    return(list(hours = NA_real_, slope = NA_real_, intercept = NA_real_,
                message = "need at least 3 hourly means to draw a line"))
  }

  fit <- stats::lm(mean ~ hour, data = data.frame(mean = subgroup_means[ok], hour = hour[ok]))
  intercept <- unname(stats::coef(fit)[1])
  slope <- unname(stats::coef(fit)[2])
  last <- intercept + slope * (n - 1) # the line's value at the last hour

  if (last < lsl || last > usl) {
    return(list(hours = 0, slope = slope, intercept = intercept, message = "already outside the spec"))
  }
  if (abs(slope) < 1e-12) { # numerically flat
    return(list(hours = Inf, slope = slope, intercept = intercept, message = "no crossing"))
  }

  hours <- if (slope > 0) (usl - last) / slope else (lsl - last) / slope
  if (hours < 0) {
    return(list(hours = Inf, slope = slope, intercept = intercept, message = "no crossing"))
  }
  list(hours = hours, slope = slope, intercept = intercept, message = "")
}

# Ppk over a trailing window of raw readings (96 readings = 24 hours at 15 minutes).
# Both sigmas are the window's own sd, because a rolling index is a performance index.
# Returns one value per window end, from reading `window` to the last reading.
# A window with sd 0 gives NA.
rolling_ppk <- function(values, lsl = 1, usl = 6, window = 96) {
  n <- length(values)
  if (n < window) {
    return(numeric(0))
  }
  ends <- window:n
  out <- rep(NA_real_, length(ends))
  for (k in seq_along(ends)) {
    w <- values[(ends[k] - window + 1):ends[k]]
    s <- stats::sd(w)
    out[k] <- capability_indices(mean(w), s, s, lsl, usl)$ppk
  }
  out
}
