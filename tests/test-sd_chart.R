# H-10: the standard deviation (s) chart.
#
# The constants are COMPUTED from the closed form, never looked up:
#   c4 = sqrt(2/(n-1)) * Gamma(n/2) / Gamma((n-1)/2)
#   B5 = max(0, c4 - 3*sqrt(1 - c4^2))       the lower limit multiplier
#   B6 =        c4 + 3*sqrt(1 - c4^2)         the upper limit multiplier
# E[s] = c4*sigma and sd(s) = sigma*sqrt(1-c4^2), so the limits c4*sigma +/- 3*sd(s)
# are exactly B5*sigma and B6*sigma. The test asserts the computed values against
# numbers derived independently, then cross-checks that they reproduce the
# standard textbook table, so the formula is confirmed rather than the table
# being the source.

library(testthat)

path <- if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R"
source(path)
data_dir <- if (file.exists("data/readings.csv")) "data" else "../data"

# ---- The closed form, written out independently of app/R/sd_constants.R -----
c4_hand <- function(n) sqrt(2 / (n - 1)) * exp(lgamma(n / 2) - lgamma((n - 1) / 2))
b56_hand <- function(n) {
  c4 <- c4_hand(n)
  c(c4 = c4, B5 = max(0, c4 - 3 * sqrt(1 - c4^2)), B6 = c4 + 3 * sqrt(1 - c4^2))
}

test_that("c4, B5 and B6 come out of the closed form for the subgroups we use", {
  for (n in c(2L, 4L)) {
    expect_equal(sd_constants(n)$c4, c4_hand(n), tolerance = 1e-12,
                 info = paste("c4 for n =", n))
    expect_equal(sd_constants(n)$B5, unname(b56_hand(n)["B5"]), tolerance = 1e-12)
    expect_equal(sd_constants(n)$B6, unname(b56_hand(n)["B6"]), tolerance = 1e-12)
  }

  # Values a teammate can check by hand. n = 4: c4 = sqrt(2/3)*Gamma(2)/Gamma(1.5)
  # = 0.8164966/0.8862269 = 0.9213177, and B6 = 0.9213177 + 3*sqrt(1-0.8488264)
  # = 2.0877494. n = 2: c4 = sqrt(2)*Gamma(1)/Gamma(0.5) = sqrt(2/pi) = 0.7978846,
  # and B6 = 0.7978846 + 3*sqrt(1-0.6366198) = 2.6063154.
  expect_equal(sd_constants(4L)$c4, 0.9213177, tolerance = 1e-7)
  expect_equal(sd_constants(4L)$B6, 2.0877494, tolerance = 1e-7)
  expect_equal(sd_constants(2L)$c4, 0.7978846, tolerance = 1e-7)
  expect_equal(sd_constants(2L)$B6, 2.6063154, tolerance = 1e-7)
})

test_that("the computed values reproduce the published table to four decimals", {
  # Cross-check only: the source is the formula above, the table is the receipt.
  table_c4 <- c("2" = 0.7979, "3" = 0.8862, "4" = 0.9213, "5" = 0.9400,
                "6" = 0.9515, "7" = 0.9594, "8" = 0.9650, "9" = 0.9693, "10" = 0.9727)
  for (nm in names(table_c4)) {
    expect_equal(round(sd_constants(as.integer(nm))$c4, 4), unname(table_c4[nm]),
                 info = paste("c4 for n =", nm))
  }
  table_b6 <- c("2" = 2.606, "4" = 2.088, "5" = 1.964, "6" = 1.874, "7" = 1.806,
                "8" = 1.751, "9" = 1.707, "10" = 1.669)
  for (nm in names(table_b6)) {
    expect_equal(round(sd_constants(as.integer(nm))$B6, 3), unname(table_b6[nm]),
                 info = paste("B6 for n =", nm))
  }
})

test_that("B5 is computed, not hardcoded to zero", {
  # At n = 25 the lower limit is positive. Any implementation that clamps the
  # lower limit to 0 unconditionally fails here.
  s <- sd_constants(25L)
  expect_gt(s$B5, 0)
  expect_equal(s$B5, 0.5589347, tolerance = 1e-7)
  expect_equal(s$B6, 1.4203460, tolerance = 1e-7)
  expect_equal(s$c4, 0.9896404, tolerance = 1e-7)
})

test_that("sd_constants rejects a subgroup that cannot have a standard deviation", {
  expect_error(sd_constants(1), "at least 2")
  expect_error(sd_constants(0), "at least 2")
  expect_error(sd_constants(2.5), "whole number")
  expect_error(sd_constants("4"), "whole number")
  expect_error(sd_constants(c(2, 4)), "single")
  expect_error(sd_constants(NA), "single")
})

# ---- The limits themselves ----------------------------------------------------------------------

test_that("sd limits put the center at c4*sigma and the lines at B5*sigma and B6*sigma", {
  # Compared at full precision against the closed form; the rounded textbook
  # values are checked separately below, where 1e-7 is the honest tolerance.
  s <- sd_chart_limits(0.15, 4L)
  expect_equal(s$center, c4_hand(4L) * 0.15, tolerance = 1e-12)
  expect_equal(s$ucl, unname(b56_hand(4L)["B6"]) * 0.15, tolerance = 1e-12)
  expect_equal(s$lcl, 0, tolerance = 1e-12)   # B5 = 0 at n = 4
  expect_equal(s$c4, sd_constants(4L)$c4)
})

test_that("the lower limit is held at 0 when it would be negative", {
  # B5 is already clamped at 0 for n < about 20, and the limit is additionally
  # held at 0 because a standard deviation cannot be negative.
  expect_gte(sd_chart_limits(0.15, 4L)$lcl, 0)
  expect_gte(sd_chart_limits(0.15, 2L)$lcl, 0)
  expect_gte(sd_chart_limits(1.5, 25L)$lcl, 0)
})

test_that("a sigma of 0 collapses the limits onto the center, and that is allowed", {
  s <- sd_chart_limits(0, 4L)
  expect_equal(s$center, 0)
  expect_equal(s$lcl, 0)
  expect_equal(s$ucl, 0)
})

# ---- The degenerate case: constant readings -----------------------------------------------------

test_that("constant readings flag nothing on the s-chart", {
  # One fridge, four readings an hour, every reading exactly 3.5 C.
  # Every subgroup standard deviation is 0 and every limit is 0, so a point
  # sitting exactly on the center is not a flag: the comparison is strict.
  n_hours <- 30L
  values <- rep(3.5, n_hours * 4L)
  readings <- data.frame(
    fridge_id = rep("FX", length(values)),
    timestamp = as.POSIXct("2026-10-01 00:00:00", tz = "UTC") + 15 * 60 * seq_along(values) - 15 * 60,
    temp_c = values
  )
  a <- analyze_fridge(readings, fridge_id = "FX", blood_units = 10)

  expect_true(a$has_limits)
  expect_equal(unique(a$subgroups$sd), 0)
  expect_equal(a$baseline$limits$sd$center, 0)
  expect_equal(a$baseline$limits$sd$lcl, 0)
  expect_equal(a$baseline$limits$sd$ucl, 0)
  expect_equal(a$sd_test$indices, integer(0))
  expect_false(any(a$sd_flagged))
})

# ---- The chart must not move a single published number -------------------------------------------

test_that("the s-chart changed no published number for any demo fridge", {
  # Captured from analyze_all() BEFORE the chart existed. If any of these drift,
  # the chart has leaked into the badge, the RPN, the capability or the
  # violations table, which is the one thing it must never do.
  expected <- list(
    F02 = list(status = "red", rpn = 900, severity = 9, occurrence = 10, urgency = 10,
               cpk = 6.1514253024, ppk = 5.8635949946, gap = 0.2878303078,
               units_at_risk = 180, blood_units = 180, hours_text = "already out",
               lag1 = 0.1041215533, violations = 573L, charts = "X-bar,Range"),
    F04 = list(status = "red", rpn = 100, severity = 10, occurrence = 10, urgency = 1,
               cpk = 6.2806962334, ppk = 6.1330157061, gap = 0.1476805272,
               units_at_risk = 0, blood_units = 220, hours_text = "> 72 h",
               lag1 = 0.0515223939, violations = 15L, charts = "X-bar,Range"),
    F06 = list(status = "red", rpn = 54, severity = 6, occurrence = 9, urgency = 1,
               cpk = 5.9127169864, ppk = 6.0778081150, gap = -0.1650911286,
               units_at_risk = 55, blood_units = 55, hours_text = "> 72 h",
               lag1 = -0.1244811141, violations = 11L, charts = "Range,X-bar"),
    F03 = list(status = "red", rpn = 50, severity = 5, occurrence = 10, urgency = 1,
               cpk = 5.8129580825, ppk = 5.5826558831, gap = 0.2303021994,
               units_at_risk = 40, blood_units = 40, hours_text = "> 72 h",
               lag1 = 0.0134828459, violations = 16L, charts = "X-bar,Range"),
    F05 = list(status = "amber", rpn = 18, severity = 3, occurrence = 6, urgency = 1,
               cpk = 4.9469091153, ppk = 5.1205119521, gap = -0.1736028369,
               units_at_risk = 8, blood_units = 8, hours_text = "> 72 h",
               lag1 = -0.1479448778, violations = 69L, charts = "X-bar"),
    F01 = list(status = "amber", rpn = 15, severity = 3, occurrence = 5, urgency = 1,
               cpk = 5.4741169973, ppk = 5.5360808058, gap = -0.0619638085,
               units_at_risk = 0, blood_units = 12, hours_text = "> 72 h",
               lag1 = 0.0229965294, violations = 6L, charts = "Range,X-bar")
  )

  loaded <- load_demo_data(data_dir)
  analyses <- analyze_all(loaded$readings, loaded$inventory)

  expect_setequal(names(analyses), names(expected))
  for (id in names(expected)) {
    a <- analyses[[id]]
    e <- expected[[id]]
    expect_identical(a$status, e$status, info = paste(id, "status"))
    expect_equal(a$rpn, e$rpn, tolerance = 1e-9, info = paste(id, "rpn"))
    expect_equal(a$severity, e$severity, tolerance = 1e-9, info = paste(id, "severity"))
    expect_equal(a$occurrence, e$occurrence, tolerance = 1e-9, info = paste(id, "occurrence"))
    expect_equal(a$urgency, e$urgency, tolerance = 1e-9, info = paste(id, "urgency"))
    expect_equal(a$cpk, e$cpk, tolerance = 1e-9, info = paste(id, "cpk"))
    expect_equal(a$ppk, e$ppk, tolerance = 1e-9, info = paste(id, "ppk"))
    expect_equal(a$gap, e$gap, tolerance = 1e-9, info = paste(id, "gap"))
    expect_equal(a$units_at_risk, e$units_at_risk, tolerance = 1e-9, info = paste(id, "units_at_risk"))
    expect_equal(a$blood_units, e$blood_units, tolerance = 1e-9, info = paste(id, "blood_units"))
    expect_identical(a$hours_text, e$hours_text, info = paste(id, "hours_text"))
    expect_equal(a$lag1, e$lag1, tolerance = 1e-9, info = paste(id, "lag1"))
    expect_equal(nrow(a$violations), e$violations, info = paste(id, "violations"))
    expect_identical(paste(unique(a$violations$chart), collapse = ","), e$charts,
                     info = paste(id, "violation charts"))
  }
})

test_that("the s-chart's own flags never reach the violations table", {
  loaded <- load_demo_data(data_dir)
  analyses <- analyze_all(loaded$readings, loaded$inventory)
  for (id in names(analyses)) {
    a <- analyses[[id]]
    # The violations table only ever names the X-bar and Range charts.
    expect_true(all(a$violations$chart %in% c("X-bar", "Range")),
                info = paste(id, "violations must not name the s-chart"))
    # And the s-chart carries its own flag vector, parallel to the subgroups.
    expect_true(length(a$sd_flagged) == nrow(a$subgroups),
                info = paste(id, "sd_flagged length"))
  }
})

test_that("the s-chart exists on every demo fridge and its limits are frozen", {
  loaded <- load_demo_data(data_dir)
  analyses <- analyze_all(loaded$readings, loaded$inventory)
  for (id in names(analyses)) {
    a <- analyses[[id]]
    lim <- a$baseline$limits$sd
    expect_false(is.null(lim), info = paste(id, "s-chart limits"))
    expect_true(all(is.finite(lim$center)), info = paste(id, "center finite"))
    expect_true(all(is.finite(lim$ucl)), info = paste(id, "ucl finite"))
    expect_true(lim$lcl >= 0, info = paste(id, "lcl non-negative"))
    expect_true(lim$lcl <= lim$center, info = paste(id, "lcl <= center"))
    expect_true(lim$ucl >= lim$center, info = paste(id, "ucl >= center"))
    # Frozen: the center is c4 * sigma_short from the baseline window alone.
    expect_equal(lim$center, lim$c4 * a$baseline$sigma_short, tolerance = 1e-12,
                 info = paste(id, "center = c4 * sigma_short"))
  }
})

test_that("an s-chart point past the limits is flagged by test 1, strictly", {
  # Lower limit is 0 at n = 4, so only the upper limit can fire. A point exactly
  # on the line is not a flag.
  sigma_short <- 0.2
  lim <- sd_chart_limits(sigma_short, 4L)
  expect_equal(special_cause_test_1(lim$ucl, lim$lcl, lim$ucl)$indices, integer(0),
               info = "a point exactly on the UCL is not a flag")
  expect_equal(special_cause_test_1(lim$ucl + 1e-9, lim$lcl, lim$ucl)$indices, 1L,
               info = "a point just past the UCL is a flag")
})
