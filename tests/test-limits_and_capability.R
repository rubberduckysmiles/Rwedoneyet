source(if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R") # works from the repo root and from inside tests/
source(if (file.exists("tests/known_rows.R")) "tests/known_rows.R" else "known_rows.R")
library(testthat)

# Helper for these tests: the two sigmas from raw readings, the way freeze_baseline will do it.
sigmas_of <- function(values, n = 4) {
  st <- subgroup_stats(values, n)
  list(
    short = sigma_short_from_variances(st$variance),
    overall = sigma_overall(values),
    center = mean(st$mean)
  )
}

test_that("X-bar limits on the stable data match the SPEC known answer", {
  s <- sigmas_of(stable_values)
  lim <- xbar_limits(s$center, s$short, n = 4)
  expect_equal(lim$center, key$center, tolerance = 1e-6)
  expect_equal(lim$lcl, key$xbar_lcl, tolerance = 1e-6)
  expect_equal(lim$ucl, key$xbar_ucl, tolerance = 1e-6)
  expect_equal(lim$se, key$sigma_short / 2, tolerance = 1e-6)
  expect_equal(lim$zone1, lim$se, tolerance = 1e-12)
  expect_equal(lim$zone2, 2 * lim$se, tolerance = 1e-12)
  expect_equal(lim$zone3, 3 * lim$se, tolerance = 1e-12)
})

test_that("range chart limits on the stable data match the SPEC known answer", {
  s <- sigmas_of(stable_values)
  lim <- range_chart_limits(s$short, n = 4)
  expect_equal(lim$center, key$range_center, tolerance = 1e-6)
  expect_equal(lim$ucl, key$range_ucl, tolerance = 1e-6)
  expect_equal(lim$lcl, 0)
  expect_equal(lim$d2, key$d2_n4, tolerance = 1e-6)
  expect_equal(lim$d3, key$d3_n4, tolerance = 1e-6)
})

test_that("the range chart lower limit is held at 0, not negative", {
  # For n = 4, d2 - 3 * d3 is negative, so the unclipped value would be below 0.
  lim <- range_chart_limits(1, n = 4)
  expect_true(lim$d2 - 3 * lim$d3 < 0)
  expect_equal(lim$lcl, 0)
})

test_that("Cpk, Ppk and the gap on the stable data match the SPEC known answer", {
  s <- sigmas_of(stable_values)
  cap <- capability_indices(s$center, s$short, s$overall)
  expect_equal(cap$cpk, key$cpk, tolerance = 1e-6)
  expect_equal(cap$ppk, key$ppk, tolerance = 1e-6)
  expect_equal(cap$gap, key$gap, tolerance = 1e-6)
  expect_equal(cap$message, "")
})

test_that("the drift check matches the SPEC known answer", {
  s <- sigmas_of(drift_values)
  expect_equal(s$center, key$drift_center, tolerance = 1e-6)
  expect_equal(s$short, key$sigma_short, tolerance = 1e-6) # drift moves the hour means, not the within-hour spread
  expect_equal(s$overall, key$drift_sigma_overall, tolerance = 1e-6)
  cap <- capability_indices(s$center, s$short, s$overall)
  expect_equal(cap$cpk, key$drift_cpk, tolerance = 1e-6)
  expect_equal(cap$ppk, key$drift_ppk, tolerance = 1e-6)
  expect_equal(cap$gap, key$drift_gap, tolerance = 1e-6)
})

test_that("constant data: both sigmas are 0 and Cpk, Ppk and gap are NA with a message", {
  values <- rep(3.5, 40)
  s <- sigmas_of(values)
  expect_equal(s$short, 0)
  expect_equal(s$overall, 0)

  cap <- capability_indices(s$center, s$short, s$overall)
  expect_true(is.na(cap$cpk))
  expect_true(is.na(cap$ppk))
  expect_true(is.na(cap$gap))
  expect_match(cap$message, "undefined")
  expect_equal(cap$message, "sigma is 0; Cpk and Ppk are undefined")
  # Not infinity, and not a confident 0
  expect_false(isTRUE(cap$cpk == 0))
  expect_false(any(is.infinite(c(cap$cpk, cap$ppk, cap$gap))))

  x <- xbar_limits(s$center, s$short, n = 4)
  expect_equal(x$lcl, 3.5)
  expect_equal(x$ucl, 3.5)
  expect_equal(x$se, 0)
  expect_false(any(is.infinite(unlist(x))))

  r <- range_chart_limits(s$short, n = 4)
  expect_equal(r$center, 0)
  expect_equal(r$lcl, 0)
  expect_equal(r$ucl, 0)
  expect_false(any(is.infinite(unlist(r))))
})

test_that("only one sigma at 0 still gives a gap of NA and a message", {
  cap <- capability_indices(3.5, 0.2, 0)
  expect_true(is.na(cap$ppk))
  expect_true(is.na(cap$gap))
  expect_false(is.na(cap$cpk))
  expect_match(cap$message, "undefined")
  cap2 <- capability_indices(3.5, 0, 0.2)
  expect_true(is.na(cap2$cpk))
  expect_true(is.na(cap2$gap))
  expect_false(is.na(cap2$ppk))
})

test_that("a missing sigma gives NA with a message, never a number", {
  cap <- capability_indices(3.5, NA_real_, 0.2)
  expect_true(is.na(cap$cpk))
  expect_true(is.na(cap$gap))
  expect_match(cap$message, "undefined")
})

test_that("Cpk uses the nearer spec limit, so an off-center process scores lower", {
  # mean 5 is 1 from the upper limit 6: numerator 1, sigma 0.5 -> 1 / 1.5
  cap <- capability_indices(5, 0.5, 0.5)
  expect_equal(cap$cpk, 1 / 1.5, tolerance = 1e-9)
  expect_equal(cap$gap, 0, tolerance = 1e-12)
})
