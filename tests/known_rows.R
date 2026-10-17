# Shared 10-hour known-answer data from SPEC.md section 4.
# This file does not start with "test", so testthat::test_dir() does not run it as a test.
# Each test file sources it.

# Rows are subgroups (one hour of four readings). Every hour mean is exactly 3.5.
stable_rows <- matrix(
  c(
    3.2, 3.4, 3.6, 3.8,
    3.3, 3.5, 3.5, 3.7,
    3.1, 3.4, 3.6, 3.9,
    3.4, 3.4, 3.6, 3.6,
    3.0, 3.5, 3.5, 4.0,
    3.2, 3.3, 3.7, 3.8,
    3.3, 3.4, 3.6, 3.7,
    3.1, 3.5, 3.5, 3.9,
    3.2, 3.6, 3.6, 3.6,
    3.4, 3.5, 3.5, 3.6
  ),
  ncol = 4, byrow = TRUE
)

# Drift check: add 0, 0, 0, 0, 0, 0.2, 0.4, 0.6, 0.8, 1.0 to each of the four readings in that hour.
drift_offsets <- c(0, 0, 0, 0, 0, 0.2, 0.4, 0.6, 0.8, 1.0)
drift_rows <- stable_rows + drift_offsets # a length-10 vector recycles down each column: one offset per row

# Raw readings in time order (row by row).
stable_values <- as.vector(t(stable_rows))
drift_values <- as.vector(t(drift_rows))

# Answer key copied from SPEC.md section 4.
key <- list(
  sigma_short = 0.2569046516,
  sigma_overall = 0.2253202849,
  center = 3.5,
  xbar_lcl = 3.1146430226,
  xbar_ucl = 3.8853569774,
  d2_n4 = 2.0587507460,
  d3_n4 = 0.8798082028,
  d2_n5 = 2.3259289473,
  d3_n5 = 0.8640819411,
  range_center = 0.5289026431,
  range_ucl = 1.2069831025,
  range_lcl = 0,
  cpk = 3.2437456007,
  ppk = 3.6984390192,
  gap = -0.4546934185,
  lag1 = -0.2174115934,
  drift_center = 3.8,
  drift_sigma_overall = 0.4290717470,
  drift_cpk = 2.8544961286,
  drift_ppk = 1.7091158726,
  drift_gap = 1.1453802560
)
