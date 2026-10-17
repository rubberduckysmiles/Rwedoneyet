source(if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R") # works from the repo root and from inside tests/
source(if (file.exists("tests/known_rows.R")) "tests/known_rows.R" else "known_rows.R")
library(testthat)

test_that("subgroup_stats splits the stable readings into 10 groups of 4", {
  st <- subgroup_stats(stable_values, n = 4)
  expect_equal(names(st), c("subgroup", "mean", "variance", "sd", "range", "n_obs"))
  expect_equal(nrow(st), 10)
  expect_equal(st$subgroup, 1:10)
  expect_equal(st$n_obs, rep(4L, 10))
  expect_equal(st$mean, rep(3.5, 10), tolerance = 1e-9)
  # Hour 1 by hand: readings 3.2 3.4 3.6 3.8, mean 3.5, squares of deviations 0.09+0.01+0.01+0.09 = 0.2, variance 0.2 / 3
  expect_equal(st$variance[1], 0.2 / 3, tolerance = 1e-9)
  expect_equal(st$sd[1], sqrt(0.2 / 3), tolerance = 1e-9)
  expect_equal(st$range[1], 0.6, tolerance = 1e-9)
  # Sum of squares across the ten hours is 1.98, so the mean variance is 1.98 / 30 = 0.066
  expect_equal(mean(st$variance), 0.066, tolerance = 1e-9)
})

test_that("subgroup_stats with n = 1 gives variance NA and a message", {
  st <- subgroup_stats(3.5, n = 1)
  expect_equal(nrow(st), 1)
  expect_true(is.na(st$variance))
  expect_true(is.na(st$sd))
  expect_false(any(is.infinite(unlist(st))))
  expect_match(attr(st, "message"), "undefined")
  expect_match(attr(st, "message"), "variance")
})

test_that("a short last group is kept, with variance NA and a message", {
  st <- subgroup_stats(c(3.2, 3.4, 3.6, 3.8, 3.5), n = 4)
  expect_equal(nrow(st), 2)
  expect_equal(st$n_obs, c(4L, 1L))
  expect_true(is.na(st$variance[2]))
  expect_match(attr(st, "message"), "undefined")
})

test_that("a full set of groups has an empty message", {
  expect_equal(attr(subgroup_stats(stable_values, n = 4), "message"), "")
})

test_that("sigma_short is the square root of the mean within-subgroup variance", {
  st <- subgroup_stats(stable_values, n = 4)
  expect_equal(sigma_short_from_variances(st$variance), key$sigma_short, tolerance = 1e-6)
})

test_that("sigma_short is NA with a message when any variance is missing", {
  s <- sigma_short_from_variances(c(0.1, NA, 0.2))
  expect_true(is.na(s))
  expect_match(attr(s, "message"), "missing")
  expect_true(is.na(sigma_short_from_variances(numeric(0))))
})

test_that("sigma_overall is the sample sd of every reading", {
  expect_equal(sigma_overall(stable_values), key$sigma_overall, tolerance = 1e-6)
  expect_equal(sigma_overall(drift_values), key$drift_sigma_overall, tolerance = 1e-6)
})

test_that("lag-1 autocorrelation matches the SPEC known answer", {
  expect_equal(lag1_autocorrelation(stable_values), key$lag1, tolerance = 1e-6)
})

test_that("lag-1 autocorrelation is NA with a message for fewer than 3 readings", {
  r <- lag1_autocorrelation(c(3.5, 3.6))
  expect_true(is.na(r))
  expect_true(nzchar(attr(r, "message")))
})

test_that("lag-1 autocorrelation of constant data is NA with a message, not a warning", {
  expect_no_warning(r <- lag1_autocorrelation(rep(3.5, 40)))
  expect_true(is.na(r))
  expect_match(attr(r, "message"), "undefined")
})
