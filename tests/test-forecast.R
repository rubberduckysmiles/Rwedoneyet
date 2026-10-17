source(if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R") # works from the repo root and from inside tests/
source(if (file.exists("tests/known_rows.R")) "tests/known_rows.R" else "known_rows.R")
library(testthat)

test_that("hours_to_spec on a rising line reaches 6 C in 6 hours", {
  f <- hours_to_spec(c(4.0, 4.2, 4.4, 4.6, 4.8))
  expect_equal(f$slope, 0.2, tolerance = 1e-9)
  expect_equal(f$intercept, 4.0, tolerance = 1e-9)
  expect_equal(f$hours, 6, tolerance = 1e-9) # (6 - 4.8) / 0.2
})

test_that("hours_to_spec on a falling line heads for 1 C", {
  f <- hours_to_spec(c(3.0, 2.8, 2.6, 2.4, 2.2))
  expect_equal(f$slope, -0.2, tolerance = 1e-9)
  expect_equal(f$hours, 6, tolerance = 1e-9) # (1 - 2.2) / -0.2
})

test_that("a series already outside the spec gives 0 hours", {
  expect_equal(hours_to_spec(c(6.2, 6.3, 6.4))$hours, 0)
  expect_equal(hours_to_spec(c(0.8, 0.7, 0.6))$hours, 0)
})

test_that("a flat series gives Inf and a no-crossing message", {
  f <- hours_to_spec(c(3.5, 3.5, 3.5, 3.5))
  expect_identical(f$hours, Inf)
  expect_match(f$message, "no crossing")
})

test_that("a rising line inside the spec heads for the upper limit, not the lower", {
  f <- hours_to_spec(c(2.0, 2.5, 3.0))
  expect_equal(f$hours, 6, tolerance = 1e-9) # (6 - 3.0) / 0.5
})

test_that("fewer than 3 means gives NA with a message", {
  f <- hours_to_spec(c(4.0, 4.2))
  expect_true(is.na(f$hours))
  expect_true(nzchar(f$message))
})

test_that("rolling_ppk returns one value per window end and matches a hand calculation", {
  values <- rep(c(3, 4), 100) # 200 readings alternating 3 and 4
  r <- rolling_ppk(values, window = 96)
  expect_equal(length(r), 200 - 96 + 1)
  w1 <- values[1:96]
  expect_equal(r[1], min(6 - mean(w1), mean(w1) - 1) / (3 * sd(w1)), tolerance = 1e-9)
  w_last <- values[105:200]
  expect_equal(r[105], min(6 - mean(w_last), mean(w_last) - 1) / (3 * sd(w_last)), tolerance = 1e-9)
})

test_that("rolling_ppk is NA where the window sd is 0, never Inf", {
  r <- rolling_ppk(rep(3.5, 120), window = 96)
  expect_equal(length(r), 25)
  expect_true(all(is.na(r)))
  expect_false(any(is.infinite(r)))
})

test_that("rolling_ppk on fewer readings than the window is an empty vector", {
  expect_equal(length(rolling_ppk(c(3, 4, 3), window = 96)), 0)
})
