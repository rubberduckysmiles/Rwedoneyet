source(if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R") # works from the repo root and from inside tests/
library(testthat)

test_that("test 1 flags a point strictly outside the limits", {
  r <- special_cause_test_1(c(0, 0, 4), lower = -3, upper = 3)
  expect_equal(r$indices, 3L)
  expect_true(is.character(r$meaning) && length(r$meaning) == 1)
  expect_equal(r$meaning, "One point outside the 3-sigma limits. A sudden temperature excursion.")
  # A point exactly on a limit is not a flag
  expect_equal(length(special_cause_test_1(c(3), lower = -3, upper = 3)$indices), 0)
  expect_equal(length(special_cause_test_1(c(-3), lower = -3, upper = 3)$indices), 0)
  expect_equal(special_cause_test_1(c(-3.1, 0, 3.1), lower = -3, upper = 3)$indices, c(1L, 3L))
})

test_that("test 2 flags the 9th point of nine on one side of the center", {
  expect_equal(special_cause_test_2(rep(1, 9), center = 0)$indices, 9L)
  expect_equal(length(special_cause_test_2(rep(1, 8), center = 0)$indices), 0)
  # A point equal to the center breaks the run
  expect_equal(length(special_cause_test_2(c(rep(1, 4), 0, rep(1, 4)), center = 0)$indices), 0)
  # A run that continues flags the 9th, 10th, ...
  expect_equal(special_cause_test_2(rep(-1, 11), center = 0)$indices, 9:11)
  # Crossing the center breaks the run
  expect_equal(length(special_cause_test_2(c(rep(1, 5), rep(-1, 5)), center = 0)$indices), 0)
  expect_equal(special_cause_test_2(rep(1, 9), center = 0)$meaning,
               "Nine points in a row on one side of the center. The fridge has shifted.")
})

test_that("test 3 flags the 6th point of six rising or falling", {
  expect_equal(special_cause_test_3(c(1, 2, 3, 4, 5, 6))$indices, 6L)
  expect_equal(length(special_cause_test_3(c(1, 2, 3, 4, 5))$indices), 0)
  expect_equal(special_cause_test_3(c(6, 5, 4, 3, 2, 1))$indices, 6L)
  expect_equal(special_cause_test_3(c(1, 2, 3, 4, 5, 6, 7, 8))$indices, 6:8)
  # Equal neighbours break the run
  expect_equal(length(special_cause_test_3(c(1, 2, 3, 3, 4, 5, 6))$indices), 0)
  expect_match(special_cause_test_3(c(1, 2, 3, 4, 5, 6))$meaning, "compressor")
})

test_that("test 4 flags the 14th point of fourteen alternating", {
  expect_equal(special_cause_test_4(rep(c(0, 1), 7))$indices, 14L)
  expect_equal(length(special_cause_test_4(rep(c(0, 1), 7)[1:13])$indices), 0)
  expect_equal(special_cause_test_4(rep(c(0, 1), 8))$indices, 14:16)
  # An equal pair breaks the run
  broken <- rep(c(0, 1), 7)
  broken[7] <- broken[6]
  expect_equal(length(special_cause_test_4(broken)$indices), 0)
  expect_match(special_cause_test_4(rep(c(0, 1), 7))$meaning, "hunting")
})

test_that("test 5 flags two of three beyond 2 sigma on the same side", {
  expect_equal(special_cause_test_5(c(2.5, 2.5, 0), center = 0, se = 1)$indices, 3L)
  expect_equal(length(special_cause_test_5(c(2.5, 0, 0), center = 0, se = 1)$indices), 0)
  # Opposite sides do not count together
  expect_equal(length(special_cause_test_5(c(2.5, -2.5, 0), center = 0, se = 1)$indices), 0)
  # Exactly 2 sigma is not beyond
  expect_equal(length(special_cause_test_5(c(2, 2, 0), center = 0, se = 1)$indices), 0)
  expect_equal(special_cause_test_5(c(-2.5, 0, -2.5), center = 0, se = 1)$indices, 3L)
  expect_match(special_cause_test_5(c(2.5, 2.5, 0), center = 0, se = 1)$meaning, "Two of three")
})

test_that("test 6 flags four of five beyond 1 sigma on the same side", {
  expect_equal(special_cause_test_6(c(1.5, 1.5, 1.5, 1.5, 0), center = 0, se = 1)$indices, 5L)
  expect_equal(length(special_cause_test_6(c(1.5, 1.5, 1.5, 0, 0), center = 0, se = 1)$indices), 0)
  # Exactly 1 sigma is not beyond
  expect_equal(length(special_cause_test_6(c(1, 1, 1, 1, 0), center = 0, se = 1)$indices), 0)
  expect_match(special_cause_test_6(c(1.5, 1.5, 1.5, 1.5, 0), center = 0, se = 1)$meaning, "Four of five")
})

test_that("test 7 flags fifteen points in a row inside 1 sigma", {
  expect_equal(special_cause_test_7(rep(0, 15), center = 0, se = 1)$indices, 15L)
  expect_equal(length(special_cause_test_7(rep(0, 14), center = 0, se = 1)$indices), 0)
  expect_equal(special_cause_test_7(rep(0, 17), center = 0, se = 1)$indices, 15:17)
  # A point exactly 1 sigma away does not count as inside
  expect_equal(length(special_cause_test_7(c(rep(0, 7), 1, rep(0, 7)), center = 0, se = 1)$indices), 0)
  # Both sides are allowed
  expect_equal(special_cause_test_7(rep(c(-0.5, 0.5), length.out = 15), center = 0, se = 1)$indices, 15L)
  expect_match(special_cause_test_7(rep(0, 15), center = 0, se = 1)$meaning, "stuck sensor")
})

test_that("test 8 flags eight points in a row outside 1 sigma, either side", {
  expect_equal(special_cause_test_8(rep(2, 8), center = 0, se = 1)$indices, 8L)
  expect_equal(length(special_cause_test_8(rep(2, 7), center = 0, se = 1)$indices), 0)
  # A mix of sides counts
  expect_equal(special_cause_test_8(rep(c(2, -2), 4), center = 0, se = 1)$indices, 8L)
  expect_equal(special_cause_test_8(rep(c(2, -2), 5), center = 0, se = 1)$indices, 8:10)
  # One point inside breaks the run
  expect_equal(length(special_cause_test_8(c(rep(2, 4), 0.5, rep(2, 4)), center = 0, se = 1)$indices), 0)
  expect_match(special_cause_test_8(rep(2, 8), center = 0, se = 1)$meaning, "Two regimes")
})

test_that("every rule returns integer indices and one meaning string, even with no flags", {
  quiet <- c(0, 0.2, -0.3, 0.1)
  results <- list(
    special_cause_test_1(quiet, -3, 3),
    special_cause_test_2(quiet, 0),
    special_cause_test_3(quiet),
    special_cause_test_4(quiet),
    special_cause_test_5(quiet, 0, 1),
    special_cause_test_6(quiet, 0, 1),
    special_cause_test_7(quiet, 0, 1),
    special_cause_test_8(quiet, 0, 1)
  )
  for (r in results) {
    expect_named(r, c("indices", "meaning"))
    expect_true(is.integer(r$indices))
    expect_true(is.character(r$meaning) && length(r$meaning) == 1 && nzchar(r$meaning))
  }
})

test_that("the flag functions do not call each other", {
  src <- readLines(if (file.exists("app/R/special_cause_tests.R")) "app/R/special_cause_tests.R" else "../app/R/special_cause_tests.R")
  code <- paste(src[!grepl("^\\s*#", src)], collapse = "\n")
  # split the file into the eight function bodies and check none mentions another test's name
  for (k in 1:8) {
    start <- regexpr(paste0("special_cause_test_", k, " <- function"), code)
    expect_true(start > 0)
    rest <- substring(code, start + 1)
    nxt <- regexpr("\nspecial_cause_test_[0-9] <- function", rest)
    body <- if (nxt > 0) substring(rest, 1, nxt) else rest
    others <- setdiff(1:8, k)
    for (j in others) {
      expect_false(grepl(paste0("special_cause_test_", j, "\\("), body),
                   info = paste("test", k, "mentions test", j))
    }
  }
})
