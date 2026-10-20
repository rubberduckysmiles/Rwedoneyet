# H-25: the two committed scenario sets, driven through the same code the app runs.
#
# data/scenario_one_bad/ and data/scenario_one_good/ are hand-tuned alternatives to
# data/readings.csv (see data/README.md). The app never loads them, so until this file
# existed they were the one finished piece of work nothing exercised. Everything asserted
# below was MEASURED from the committed files with load_demo_data() plus analyze_all() -
# the same two calls app.R makes - and never assumed. If a file changes, or a statistic
# moves, these expectations fail on purpose.
#
# H-28 changed the badge rule in app/R/monitor.R: red now needs a reading outside 1-6 C or
# two test-1 points in a row inside the last day, and amber needs two flags in that day.
# The verdicts below were re-measured under that rule - measured first, then written down.
#
# The names are labels, not descriptions: the "bad" set has nothing failing, and the
# "good" set has no textbook failure either. What each set really is:
#   bad  - negative control for the range check. Six fridges of common-cause noise,
#          every reading inside 1-6 C.
#   good - four awkward cases at once: F02 riding the 1 C lower limit without ever
#          crossing it, F06 the only fridge that leaves 1-6 C, F05 with about half the
#          usual spread, F03/F04 carrying door and generator flags that never move
#          the temperature.
library(testthat)

path <- if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R"
source(path)

data_dir <- if (file.exists("data/readings.csv")) "data" else "../data"

scenarios <- c(
  bad = file.path(data_dir, "scenario_one_bad"),
  good = file.path(data_dir, "scenario_one_good")
)

loaded <- lapply(scenarios, load_demo_data)
analyses <- lapply(loaded, function(d) analyze_all(d$readings, d$inventory))
summaries <- Map(function(d, a) overview_summary(a, d$generator), loaded, analyses)

fridge <- function(set, id) {
  r <- loaded[[set]]$readings
  r[r$fridge_id == id, , drop = FALSE]
}

statuses <- function(a) vapply(a, function(x) x$status, character(1))

# Readings after the frozen 48-hour baseline, which is the window the monitor watches.
post_out_of_spec <- function(a) {
  v <- a$readings$temp_c
  p <- if (a$has_limits) v[-seq_len(a$n_baseline * 4)] else v
  sum(p < 1 | p > 6, na.rm = TRUE)
}

# Same fingerprint data/README.md prints: md5 of the bytes with line endings as LF.
lf_md5 <- function(p) {
  txt <- rawToChar(readBin(p, "raw", file.info(p)$size))
  txt <- gsub("\r\n", "\n", txt, fixed = TRUE)
  tmp <- tempfile()
  writeBin(charToRaw(txt), tmp)
  unname(tools::md5sum(tmp))
}

# ------------------------------------------------------ the files themselves

test_that("both scenario files are the committed ones and share the demo's shape", {
  expected_md5 <- c(
    bad = "a6ade73760933721328b87202e00c8a6",
    good = "2617a7f5de9679533f8d5890d0a4fb12"
  )
  for (nm in names(scenarios)) {
    expect_equal(lf_md5(file.path(scenarios[[nm]], "readings.csv")), expected_md5[[nm]],
                 info = paste(nm, "checksum, as printed in data/README.md"))

    r <- loaded[[nm]]$readings
    expect_equal(nrow(r), 4032, info = nm)
    expect_equal(sort(unique(r$fridge_id)), sprintf("F%02d", 1:6), info = nm)
    expect_equal(unname(as.integer(table(r$fridge_id))), rep(672L, 6), info = nm)
    expect_false(anyNA(r$timestamp), info = nm)
    expect_false(anyNA(r$temp_c), info = nm)

    # 672 readings 15 minutes apart is exactly the 2026-10-01 to 2026-10-07 week.
    expect_equal(format(min(r$timestamp), "%Y-%m-%d %H:%M"), "2026-10-01 00:00", info = nm)
    expect_equal(format(max(r$timestamp), "%Y-%m-%d %H:%M"), "2026-10-07 23:45", info = nm)

    # Both folders carry the same inventory and backup-power log as data/.
    expect_equal(nrow(loaded[[nm]]$inventory), 40, info = nm)
    expect_equal(nrow(loaded[[nm]]$generator), 30, info = nm)
  }
})

# ------------------------------------------------------ the bad set: negative control

test_that("scenario_one_bad is common-cause noise only: nothing leaves 1-6 C", {
  expected <- data.frame(
    fridge_id = sprintf("F%02d", 1:6),
    mean = c(3.494, 3.502, 3.507, 3.507, 3.501, 3.499),
    sd   = c(0.152, 0.148, 0.155, 0.149, 0.145, 0.155),
    min  = c(3.09, 3.09, 3.09, 3.09, 3.10, 3.09),
    max  = rep(3.91, 6)
  )
  for (i in seq_len(nrow(expected))) {
    id <- expected$fridge_id[i]
    r <- fridge("bad", id)
    expect_equal(round(mean(r$temp_c), 3), expected$mean[i], info = id)
    expect_equal(round(stats::sd(r$temp_c), 3), expected$sd[i], info = id)
    expect_equal(min(r$temp_c), expected$min[i], info = id)
    expect_equal(max(r$temp_c), expected$max[i], info = id)
    # The whole point of this file: no reading out of range, and no operator evidence.
    expect_equal(sum(r$temp_c < 1 | r$temp_c > 6), 0L, info = id)
    expect_equal(sum(r$door_open == 1, na.rm = TRUE), 0L, info = id)
    expect_equal(sum(r$on_generator == 1, na.rm = TRUE), 0L, info = id)
  }
})

# ------------------------------------------------------ the good set: awkward cases

test_that("scenario_one_good carries the awkward cases the codebook names", {
  f2 <- fridge("good", "F02")
  # F02 rides the lower limit all week: 618 of 672 readings under 2 C, 54 exactly at 1.00,
  # and not one of them below 1 C. A range check has nothing to fire on.
  expect_equal(min(f2$temp_c), 1.00)
  expect_equal(max(f2$temp_c), 2.00)
  expect_equal(sum(f2$temp_c < 2), 618L)
  expect_equal(sum(f2$temp_c == 1), 54L)
  expect_equal(sum(f2$temp_c < 1), 0L)

  f6 <- fridge("good", "F06")
  # F06 is the only fridge of the twelve that leaves 1-6 C, and it does so intermittently.
  expect_equal(sum(f6$temp_c > 6), 16L)
  expect_equal(sum(f6$temp_c < 1), 0L)
  expect_equal(max(f6$temp_c), 6.40)
  expect_equal(format(min(f6$timestamp[f6$temp_c > 6]), "%Y-%m-%d %H:%M"), "2026-10-01 09:30")
  expect_equal(format(max(f6$timestamp[f6$temp_c > 6]), "%Y-%m-%d %H:%M"), "2026-10-07 10:30")
  for (id in c("F01", "F02", "F03", "F04", "F05")) {
    r <- fridge("good", id)
    expect_equal(sum(r$temp_c < 1 | r$temp_c > 6), 0L, info = id)
  }

  # F03 and F04: operator evidence with no temperature response.
  f3 <- fridge("good", "F03")
  expect_equal(sum(f3$door_open == 1, na.rm = TRUE), 8L)
  expect_equal(max(f3$temp_c), 4.00)
  f4 <- fridge("good", "F04")
  expect_equal(sum(f4$on_generator == 1, na.rm = TRUE), 5L)
  expect_equal(max(f4$temp_c), 3.88)

  # F05 and F01 are the two tight ones, about half the usual spread.
  expect_equal(round(stats::sd(fridge("good", "F05")$temp_c), 3), 0.066)
  expect_equal(round(stats::sd(fridge("good", "F01")$temp_c), 3), 0.075)
})

# ------------------------------------------------------ the pipeline's verdicts

test_that("the pipeline's verdicts on the bad set are the ones the files produce", {
  a <- analyses$bad

  # No fridge is red and none is out of range after the baseline - the negative control.
  # Under the H-28 badge this noise is left alone: four of the six come back green.
  expect_equal(statuses(a), c(F04 = "amber", F06 = "amber", F03 = "green",
                              F01 = "green", F05 = "green", F02 = "green"))
  expect_false(any(statuses(a) == "red"))
  expect_equal(unname(vapply(a, post_out_of_spec, 0L)), rep(0L, 6))

  # Cpk is uniformly enormous, which is what pure noise looks like.
  expect_true(all(vapply(a, function(x) x$cpk, 0) > 4))

  expect_equal(summaries$bad$needing_action, 2L)
  expect_equal(summaries$bad$units_at_risk, 275)
  expect_equal(round(summaries$bad$average_ppk, 4), 5.4245)
  expect_equal(summaries$bad$last_transfer, 48)

  # Which fridges carry the reported bags: the two with a flag in the last 24 hours.
  expect_equal(vapply(a, function(x) x$units_at_risk, 0),
               c(F04 = 220, F06 = 55, F03 = 0, F01 = 0, F05 = 0, F02 = 0))
})

test_that("on the good set the chart catches F02 while the range check cannot", {
  a <- analyses$good

  # Sorted by RPN, highest first (the order the Overview lists).
  expect_equal(statuses(a), c(F04 = "green", F06 = "red", F02 = "amber",
                              F01 = "green", F03 = "green", F05 = "green"))

  # F02: the level is wrong, the range is not. This is the case a range check misses.
  expect_equal(round(a$F02$cpk, 3), 0.537)
  expect_lt(a$F02$cpk, 1)
  expect_equal(post_out_of_spec(a$F02), 0L)

  # F06: the one fridge the range check does catch, and the chart agrees it is bad.
  expect_equal(round(a$F06$cpk, 3), 0.598)
  expect_lt(a$F06$cpk, 1)
  expect_equal(post_out_of_spec(a$F06), 11L)

  # F05 is tight and well behaved: the chart does not over-react to a settled sensor.
  expect_equal(a$F05$status, "green")
  expect_equal(nrow(a$F05$violations), 0L)

  # F03 and F04 flap between flags with no temperature story, and F01's tight baseline
  # limits catch a single recent point. One isolated flag no longer reaches the badge
  # (H-28 needs two in the day), so all three are green - while F01's 12 bags are still
  # reported at risk, because the bag count only needs one recent flag.
  expect_equal(sort(unique(a$F01$violations$test)), c(1L, 3L, 5L))
  expect_true(any(a$F01$violations$monitored))

  expect_equal(summaries$good$needing_action, 2L)
  expect_equal(summaries$good$units_at_risk, 67)
  expect_equal(round(summaries$good$average_ppk, 4), 5.7267)
  expect_equal(summaries$good$last_transfer, 48)
  expect_equal(vapply(a, function(x) x$units_at_risk, 0),
               c(F04 = 0, F06 = 55, F02 = 0, F01 = 12, F03 = 0, F05 = 0))
})

test_that("the range check and the chart disagree by design on both sets", {
  # The contrast the two folders exist to show: out-of-range readings are rare, and the
  # fridges that need attention are not the ones the range check picks.
  expect_equal(sum(vapply(analyses$bad, post_out_of_spec, 0L)), 0L)
  expect_equal(sum(vapply(analyses$good, post_out_of_spec, 0L)), 11L)

  # Fridges the range check flags, versus fridges the monitor calls red or amber.
  out_of_range <- function(a) {
    vapply(a, function(x) post_out_of_spec(x) > 0, logical(1))
  }
  needs_action <- function(a) statuses(a) %in% c("red", "amber")
  expect_equal(names(which(out_of_range(analyses$good))), "F06")
  # F06 is the only fridge out of range, and the only one the badge calls red; F02 needs
  # action for a reason no range check can see (a level riding the 1 C limit).
  expect_equal(names(analyses$good)[needs_action(analyses$good)], c("F06", "F02"))
})

# ------------------------------------------------------ the badge threshold itself

test_that("one lone test-1 point is not enough, two in a row are", {
  # A synthetic fridge built to isolate the badge threshold, because no committed file has
  # this shape. The hour means are held 1.6 standard errors from the centre: inside 2 SE,
  # so no test of their own, and outside 1 SE, with every third hour back near the centre
  # so the run-based tests 2, 3, 4, 6, 7 and 8 stay quiet. The four readings inside an hour
  # alternate by 0.05 C, which is what sets sigma_short and so the standard error. A later
  # hour whose four readings sit at 4.5 C is still inside 1-6 C - no reading is out of
  # range - but its mean is tens of standard errors above the centre, so test 1 fires there.
  se_offset <- rep(c(1.6, -1.6, 0.3), length.out = 168) * 0.0433
  with_spike <- function(n_hours) {
    v <- numeric(672)
    for (h in seq_len(168)) {
      v[((h - 1) * 4 + 1):(h * 4)] <- 3.5 + se_offset[h] + c(-0.05, 0.05, -0.05, 0.05)
    }
    if (n_hours > 0) v[(672 - 4 * n_hours + 1):672] <- 4.5
    analyze_fridge("FX", data.frame(
      fridge_id = "FX",
      timestamp = as.POSIXct("2026-10-01", tz = "UTC") + (seq_along(v) - 1) * 900,
      temp_c = v
    ), 0)
  }
  flagged_subgroups <- function(a) sort(unique(a$violations$subgroup[a$violations$monitored]))

  lone <- with_spike(1)
  expect_equal(flagged_subgroups(lone), 168L, info = "one hour, one flagged subgroup")
  expect_equal(sum(lone$violations$test == 1), 1L, info = "one test-1 point")
  expect_equal(sum(lone$readings$temp_c < 1 | lone$readings$temp_c > 6), 0L,
               info = "and no reading left 1-6 C")
  expect_equal(lone$status, "green",
               info = "so one hour outside the limits must not raise the badge")

  run <- with_spike(2)
  expect_equal(flagged_subgroups(run), c(167L, 168L), info = "two hours in a row")
  expect_equal(sum(run$violations$test == 1), 2L, info = "two test-1 points")
  expect_equal(sum(run$readings$temp_c < 1 | run$readings$temp_c > 6), 0L,
               info = "still nothing out of range")
  expect_equal(run$status, "red",
               info = "and that is the pattern the badge acts on")

  # The helper itself, directly: adjacency only, and a gap breaks the run.
  expect_true(two_in_a_row(c(10L, 11L)))
  expect_false(two_in_a_row(c(10L, 12L)))
  expect_false(two_in_a_row(10L))
  expect_false(two_in_a_row(integer(0)))
  expect_true(two_in_a_row(c(20L, 3L, 4L)))
})

# ------------------------------------------------------ a healthy fleet, and a real fault

test_that("the H-28 badge leaves a healthy fleet alone and still catches a real fault", {
  # H-25 measured the old badge on 200 simulated healthy fridges: 92.0% came back red or
  # amber, because any single post-baseline flag turned the badge amber. That is not a
  # data problem and not a broken formula - it is the number of chances to flag. About 120
  # post-baseline subgroups are read against 8 special-cause tests, so at a nominal
  # 3-sigma false-alarm rate a healthy fridge almost always trips something somewhere.
  # Lag-1 autocorrelation of these readings is under 0.16 (0.02 on F01 of the demo file),
  # so dependence does NOT explain it; the arithmetic does. H-28 changed the aggregation
  # and left the eight tests alone: red needs a reading outside 1-6 C or two test-1 points
  # in a row inside the last day, amber needs two flags in that day.
  #
  # Measured the same way (200 healthy iid-normal fridges, mean 3.5 C, sd 0.15 C, rounded,
  # 672 readings, baseline frozen the same way) through analyze_fridge(), and printed in
  # data/README.md and demo/alert_rate.R:
  #   the flag rate is unchanged - the eight tests still fire on noise
  #   0.0% red, 15.5% amber, 84.5% green (was 27.5% / 64.5% / 8.0%)
  # A real fault is still caught: the same fridges with a ramp that reaches 6.5 C, or with
  # a step to 5.0 C, are 100% red under the shipped rule. The bounds below are
  # deliberately loose so the check pins the behaviour, not the exact seed.
  sim <- function(values, n) {
    set.seed(5300)
    vapply(seq_len(n), function(i) {
      a <- analyze_fridge("FX", data.frame(
        fridge_id = "FX",
        timestamp = as.POSIXct("2026-10-01", tz = "UTC") + (0:671) * 900,
        temp_c = round(values(), 2)
      ), 0)
      c(flag = any(a$violations$monitored), amber = a$status == "amber",
        red = a$status == "red")
    }, logical(3))
  }

  healthy <- sim(function() stats::rnorm(672, 3.5, 0.15), 200)
  expect_true(mean(healthy["flag", ]) >= 0.75,
              info = "the eight tests still flag a healthy fridge most of the time")
  expect_equal(sum(healthy["red", ]), 0L, info = "a healthy fridge never comes back red")
  expect_true(mean(healthy["amber", ]) <= 0.30,
              info = "and only a minority of healthy fridges come back amber")

  drift <- sim(function() {
    base <- stats::rnorm(192, 3.5, 0.15)
    ramp <- stats::rnorm(480, 3.5 + seq_len(480) / 480 * 3, 0.15)
    c(base, ramp)
  }, 60)
  expect_equal(mean(drift["red", ]), 1,
               info = "a fridge drifting to 6.5 C is red on every draw")
})
