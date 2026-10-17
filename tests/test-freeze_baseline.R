source(if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R") # works from the repo root and from inside tests/
source(if (file.exists("tests/known_rows.R")) "tests/known_rows.R" else "known_rows.R")
library(testthat)

test_that("freeze_baseline on the stable pattern reproduces the SPEC numbers", {
  # Repeat the 10 stable hours 5 times: 50 hours, so the first 48 are the baseline
  # and hours 49 and 50 are ignored.
  values <- rep(stable_values, 5)
  fb <- freeze_baseline(values)
  expect_equal(fb$message, "")
  expect_equal(fb$n_baseline_subgroups, 48)
  expect_equal(fb$limits$xbar$center, 3.5, tolerance = 1e-6)
  # 48 hours = 4 full repeats (40 hours) plus the first 8 rows of the pattern, so the numbers differ
  # slightly from the 10-hour key. Check them against a direct calculation instead.
  base <- values[1:(48 * 4)]
  st <- subgroup_stats(base, 4)
  ss <- sqrt(mean(st$variance))
  expect_equal(fb$sigma_short, ss, tolerance = 1e-9)
  expect_equal(fb$sigma_overall, sd(base), tolerance = 1e-9)
  expect_equal(fb$limits$xbar$lcl, 3.5 - 3 * ss / 2, tolerance = 1e-9)
  expect_equal(fb$limits$xbar$ucl, 3.5 + 3 * ss / 2, tolerance = 1e-9)
  expect_equal(fb$lag1, cor(base[-length(base)], base[-1]), tolerance = 1e-9)
})

test_that("freeze_baseline on exactly the 10-hour key needs min_subgroups lowered, and then matches the key", {
  fb <- freeze_baseline(stable_values, min_subgroups = 10)
  expect_equal(fb$n_baseline_subgroups, 10)
  expect_equal(fb$limits$xbar$lcl, key$xbar_lcl, tolerance = 1e-6)
  expect_equal(fb$limits$xbar$ucl, key$xbar_ucl, tolerance = 1e-6)
  expect_equal(fb$limits$xbar$center, key$center, tolerance = 1e-6)
  expect_equal(fb$limits$range$center, key$range_center, tolerance = 1e-6)
  expect_equal(fb$limits$range$ucl, key$range_ucl, tolerance = 1e-6)
  expect_equal(fb$limits$range$lcl, 0)
  expect_equal(fb$capability$cpk, key$cpk, tolerance = 1e-6)
  expect_equal(fb$capability$ppk, key$ppk, tolerance = 1e-6)
  expect_equal(fb$capability$gap, key$gap, tolerance = 1e-6)
  expect_equal(fb$lag1, key$lag1, tolerance = 1e-6)
})

test_that("a shift after subgroup 48 does not move the center or the limits", {
  stable_48 <- rep(stable_values, length.out = 48 * 4) # the stable pattern repeated, 48 hours
  shifted_12 <- rep(c(6.5, 6.6, 6.7, 6.8), 12) # then 12 hours far above the upper spec
  all_60 <- c(stable_48, shifted_12)
  expect_equal(length(all_60), 60 * 4)

  fb_all <- freeze_baseline(all_60)
  fb_48 <- freeze_baseline(stable_48)

  expect_equal(fb_all$n_baseline_subgroups, 48)
  expect_equal(fb_48$n_baseline_subgroups, 48)
  expect_equal(fb_all$limits$xbar$center, fb_48$limits$xbar$center, tolerance = 1e-12)
  expect_equal(fb_all$limits$xbar$lcl, fb_48$limits$xbar$lcl, tolerance = 1e-12)
  expect_equal(fb_all$limits$xbar$ucl, fb_48$limits$xbar$ucl, tolerance = 1e-12)
  expect_equal(fb_all$limits$range$center, fb_48$limits$range$center, tolerance = 1e-12)
  expect_equal(fb_all$limits$range$ucl, fb_48$limits$range$ucl, tolerance = 1e-12)
  expect_equal(fb_all$limits$range$lcl, fb_48$limits$range$lcl, tolerance = 1e-12)
  expect_equal(fb_all$capability$cpk, fb_48$capability$cpk, tolerance = 1e-12)
  expect_equal(fb_all$capability$ppk, fb_48$capability$ppk, tolerance = 1e-12)
  expect_equal(fb_all$lag1, fb_48$lag1, tolerance = 1e-12)
  # And the center really is the stable one, not pulled toward 6.6
  expect_lt(fb_all$limits$xbar$ucl, 6)
})

test_that("fewer than 25 subgroups gives NULL limits and a short-baseline message", {
  fb <- freeze_baseline(stable_values[1:10]) # 10 raw readings = 2 full subgroups
  expect_null(fb$limits)
  expect_match(fb$message, "baseline too short")
  fb2 <- freeze_baseline(stable_values) # 10 subgroups
  expect_null(fb2$limits)
  expect_match(fb2$message, "baseline too short")
  fb3 <- freeze_baseline(rep(stable_values, length.out = 24 * 4)) # 24 subgroups, one short
  expect_null(fb3$limits)
  expect_match(fb3$message, "baseline too short")
})

test_that("exactly 25 complete subgroups is enough, and a partial last subgroup is ignored", {
  v <- rep(stable_values, length.out = 25 * 4 + 2) # 25 full hours plus 2 stray readings
  fb <- freeze_baseline(v)
  expect_false(is.null(fb$limits))
  expect_equal(fb$n_baseline_subgroups, 25)
  base <- v[1:100]
  expect_equal(fb$sigma_overall, sd(base), tolerance = 1e-9)
})

test_that("a constant baseline gives zero-width limits and NA capability with a message", {
  fb <- freeze_baseline(rep(3.5, 25 * 4))
  expect_equal(fb$sigma_short, 0)
  expect_equal(fb$sigma_overall, 0)
  expect_equal(fb$limits$xbar$lcl, 3.5)
  expect_equal(fb$limits$xbar$ucl, 3.5)
  expect_equal(fb$limits$range$ucl, 0)
  expect_true(is.na(fb$capability$cpk))
  expect_true(is.na(fb$capability$ppk))
  expect_match(fb$capability$message, "undefined")
  expect_true(is.na(fb$lag1))
})
