source(if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R") # works from the repo root and from inside tests/
library(testthat)

test_that("severity_score follows the blood-unit bands", {
  expect_equal(severity_score(0), 1)
  expect_equal(severity_score(1), 2)
  expect_equal(severity_score(5), 2)
  expect_equal(severity_score(6), 3)
  expect_equal(severity_score(12), 3)
  expect_equal(severity_score(15), 3)
  expect_equal(severity_score(16), 4)
  expect_equal(severity_score(30), 4)
  expect_equal(severity_score(31), 5)
  expect_equal(severity_score(50), 5)
  expect_equal(severity_score(51), 6)
  expect_equal(severity_score(75), 6)
  expect_equal(severity_score(76), 7)
  expect_equal(severity_score(100), 7)
  expect_equal(severity_score(101), 8)
  expect_equal(severity_score(150), 8)
  expect_equal(severity_score(151), 9)
  expect_equal(severity_score(180), 9)
  expect_equal(severity_score(200), 9)
  expect_equal(severity_score(201), 10)
  expect_equal(severity_score(220), 10)
})

test_that("severity_score refuses negative units", {
  expect_error(severity_score(-1))
})

test_that("urgency_score follows the hour bands", {
  expect_equal(urgency_score(0), 10)
  expect_equal(urgency_score(2), 10)
  expect_equal(urgency_score(3), 9)
  expect_equal(urgency_score(4), 9)
  expect_equal(urgency_score(8), 8)
  expect_equal(urgency_score(12), 7)
  expect_equal(urgency_score(18), 6)
  expect_equal(urgency_score(24), 5)
  expect_equal(urgency_score(36), 4)
  expect_equal(urgency_score(48), 3)
  expect_equal(urgency_score(72), 2)
  expect_equal(urgency_score(72.5), 1)
  expect_equal(urgency_score(100), 1)
  expect_equal(urgency_score(Inf), 1)
})

test_that("rpn multiplies the three scores", {
  expect_equal(rpn(9, 10, 8), 720)
  expect_equal(rpn(1, 1, 1), 1)
})

test_that("rpn refuses a score outside 1 to 10", {
  expect_error(rpn(0, 5, 5))
  expect_error(rpn(5, 11, 5))
  expect_error(rpn(5, 5, 0))
})

test_that("occurrence_score returns an integer 1 to 10 unchanged and refuses anything else", {
  expect_equal(occurrence_score(1), 1)
  expect_equal(occurrence_score(7), 7)
  expect_equal(occurrence_score(10), 10)
  expect_error(occurrence_score(0))
  expect_error(occurrence_score(11))
  expect_error(occurrence_score(2.5))
  expect_error(occurrence_score(NA))
})

test_that("worst_occurrence maps signals to the scale and takes the maximum", {
  none <- vector("list", 8)
  expect_equal(worst_occurrence(none, FALSE, FALSE), 1)

  one_test <- function(k) {
    l <- vector("list", 8)
    l[[k]] <- 5L
    l
  }
  expect_equal(worst_occurrence(one_test(6), FALSE, FALSE), 2)
  expect_equal(worst_occurrence(one_test(5), FALSE, FALSE), 3)
  expect_equal(worst_occurrence(one_test(8), FALSE, FALSE), 3)
  expect_equal(worst_occurrence(one_test(4), FALSE, FALSE), 4)
  expect_equal(worst_occurrence(one_test(2), FALSE, FALSE), 5)
  expect_equal(worst_occurrence(one_test(7), FALSE, FALSE), 6)
  expect_equal(worst_occurrence(one_test(3), FALSE, FALSE), 7)
  expect_equal(worst_occurrence(one_test(1), FALSE, FALSE), 9)

  # Range-chart test 1 forces at least 8
  expect_equal(worst_occurrence(none, TRUE, FALSE), 8)
  expect_equal(worst_occurrence(one_test(6), TRUE, FALSE), 8)
  expect_equal(worst_occurrence(one_test(1), TRUE, FALSE), 9)

  # Any reading outside 1 to 6 C forces 10
  expect_equal(worst_occurrence(none, FALSE, TRUE), 10)
  expect_equal(worst_occurrence(one_test(6), TRUE, TRUE), 10)

  # Several tests present: the maximum
  both <- vector("list", 8)
  both[[6]] <- 3L
  both[[3]] <- 9L
  expect_equal(worst_occurrence(both, FALSE, FALSE), 7)

  # Empty integer vectors count as no flag
  empties <- rep(list(integer(0)), 8)
  expect_equal(worst_occurrence(empties, FALSE, FALSE), 1)
})
