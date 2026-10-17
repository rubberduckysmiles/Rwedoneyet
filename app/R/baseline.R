# Freeze the baseline: limits come from the first hours of one fridge and then never change.

# values: raw readings for ONE fridge, in time order.
# Uses only the first baseline_subgroups complete subgroups (or all of them, if there are at
# least min_subgroups). Later readings cannot move the limits.
# Returns list(limits, capability, lag1, n_baseline_subgroups, sigma_short, sigma_overall,
#              center, subgroup_n, message).
# With fewer than min_subgroups complete subgroups, limits is NULL and message says the baseline is too short.
freeze_baseline <- function(values, subgroup_n = 4, baseline_subgroups = 48, min_subgroups = 25) {
  st <- subgroup_stats(values, subgroup_n)
  complete <- st[st$n_obs == subgroup_n, , drop = FALSE]

  if (nrow(complete) < min_subgroups) {
    return(list(
      limits = NULL,
      capability = NULL,
      lag1 = NULL,
      n_baseline_subgroups = 0L,
      sigma_short = NULL,
      sigma_overall = NULL,
      center = NULL,
      subgroup_n = subgroup_n,
      message = paste0(
        "baseline too short: ", nrow(complete), " complete subgroups, need at least ", min_subgroups
      )
    ))
  }

  n_base <- min(nrow(complete), baseline_subgroups)
  base <- complete[seq_len(n_base), , drop = FALSE]
  base_readings <- values[seq_len(n_base * subgroup_n)] # only the readings inside those subgroups

  sigma_short <- sigma_short_from_variances(base$variance)
  sigma_all <- sigma_overall(base_readings)
  center <- mean(base$mean)

  list(
    limits = list(
      xbar = xbar_limits(center, sigma_short, subgroup_n),
      range = range_chart_limits(sigma_short, subgroup_n)
    ),
    capability = capability_indices(center, sigma_short, sigma_all),
    lag1 = lag1_autocorrelation(base_readings),
    n_baseline_subgroups = as.integer(n_base),
    sigma_short = sigma_short,
    sigma_overall = sigma_all,
    center = center,
    subgroup_n = subgroup_n,
    message = ""
  )
}
