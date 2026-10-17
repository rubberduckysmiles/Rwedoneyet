source(if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R") # works from the repo root and from inside tests/
library(testthat)

test_that("imr_limits on c(5, 6, 5, 7) matches the formulas", {
  x <- c(5, 6, 5, 7)
  lim <- imr_limits(x)
  rc <- range_constants(2)

  expect_equal(rc$d2, 1.1283791671, tolerance = 1e-6)
  expect_equal(lim$mr_bar, 4 / 3, tolerance = 1e-9) # moving ranges 1, 1, 2
  expect_equal(lim$center, 5.75, tolerance = 1e-9)

  sigma_short <- (4 / 3) / rc$d2
  expect_equal(lim$sigma_short, sigma_short, tolerance = 1e-9)
  expect_equal(lim$lcl, 5.75 - 3 * sigma_short, tolerance = 1e-9)
  expect_equal(lim$ucl, 5.75 + 3 * sigma_short, tolerance = 1e-9)

  expect_equal(lim$mr_center, 4 / 3, tolerance = 1e-9)
  expect_equal(lim$mr_ucl, ((rc$d2 + 3 * rc$d3) / rc$d2) * (4 / 3), tolerance = 1e-9)
  # At n = 2, d2 - 3 * d3 is negative, so the moving-range lower limit is held at 0
  expect_true(rc$d2 - 3 * rc$d3 < 0)
  expect_equal(lim$mr_lcl, 0)
})

test_that("imr_limits with one value or no movement gives NA limits and a message, never Inf", {
  one <- imr_limits(5)
  expect_true(is.na(one$lcl))
  expect_true(is.na(one$ucl))
  expect_true(is.na(one$mr_ucl))
  expect_true(nzchar(one$message))

  flat <- imr_limits(c(5, 5, 5, 5))
  expect_true(is.na(flat$lcl))
  expect_true(is.na(flat$ucl))
  expect_true(is.na(flat$mr_ucl))
  expect_true(nzchar(flat$message))
  expect_false(any(is.infinite(unlist(flat[c("lcl", "ucl", "mr_lcl", "mr_ucl", "mr_center")]))))
})
