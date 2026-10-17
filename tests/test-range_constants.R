source(if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R") # works from the repo root and from inside tests/
library(testthat)

test_that("d2 and d3 for n = 4 match the SPEC known answer", {
  rc <- range_constants(4)
  expect_equal(rc$d2, 2.0587507460, tolerance = 1e-6)
  expect_equal(rc$d3, 0.8798082028, tolerance = 1e-6)
})

test_that("d2 and d3 for n = 5 match the SPEC known answer", {
  rc <- range_constants(5)
  expect_equal(rc$d2, 2.3259289473, tolerance = 1e-6)
  expect_equal(rc$d3, 0.8640819411, tolerance = 1e-6)
})

test_that("d2 for n = 2 equals 2 / sqrt(pi), the exact value", {
  rc <- range_constants(2)
  expect_equal(rc$d2, 2 / sqrt(pi), tolerance = 1e-6)
  expect_equal(rc$d2, 1.1283791671, tolerance = 1e-6)
})

test_that("range_constants refuses n below 2", {
  expect_error(range_constants(1), "at least 2")
  expect_error(range_constants(0))
  expect_error(range_constants(NA))
})
