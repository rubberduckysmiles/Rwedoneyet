# alert_rate.R - what the badge would say under four aggregation rules.
#
# H-25 found that data/scenario_one_bad has nothing outside 1-6 C yet the monitor
# reports 5 of 6 fridges needing action, and that 200 simulated HEALTHY fridges give
# 92.0% with a post-baseline flag, 64.5% amber and 27.5% red. The eight special-cause
# tests are each right; the aggregation is what makes a healthy fleet look busy. The
# badge in app/R/monitor.R turns amber on ANY single post-baseline flag and red on any
# single test-1 point or any of the last 96 readings out of range.
#
# Before anyone changes that rule, this script measures what the alternatives would do.
# It changes nothing under app/: each candidate rule is applied here to the analysis
# objects analyze_fridge() already returns, so the numbers below are the app's own
# statistics under a different decision rule.
#
# Five rules, all of them still acting on the same eight tests:
#   current     what ships today: red on one test-1 point or an out-of-range reading in
#               the last 24 h; amber on any single post-baseline flag, Cpk < 1 or a
#               forecast of 12 hours or less to the spec limit.
#   run2        a single isolated flag is not enough: red needs two test-1 points in a
#               row, amber needs two flags in a row or three flags anywhere.
#   last24      only the last 24 subgroups (one day) can set the badge, the window the
#               app already uses to decide which bags are at risk: red needs two test-1
#               points in that day, amber needs any flag in it.
#   rec_run     the same day-long window, but amber needs two flags in it, or two in a
#               row, rather than one flag.
#   rec_2d      rec_run with a two-day window (48 subgroups), so an incident that is
#               older than a day but younger than two still sets the badge.
# Cpk < 1 and a forecast of 12 hours or less keep their amber weight in every rule, so
# the slow problems the good set plants (F02 riding the 1 C limit) stay visible.
#
# Run from the repo root:  Rscript demo/alert_rate.R
#
# Three simulated populations, 200 fridges each, seed 5300, 672 readings 15 minutes
# apart, rounded to 2 decimals - the same shape as the demo files:
#   healthy   3.5 C, sd 0.15 C. Nothing is wrong. Every flag here is a false alarm.
#   drift     baseline at 3.5 C, then a straight ramp that reaches 6.5 C by the end.
#             A real problem that a monitor must keep catching.
#   step      3.5 C for the baseline, then 5.0 C with sd 0.3 C: in range but not
#             centred, the shape of the good set's warm fridge.

source(if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R")

SPEC <- c(low = 1, high = 6)
SEED <- 5300
N_SIM <- 200
N_READ <- 672

# ---- the analysis object's own view of itself ----------------------------------------------------

flag_subgroups <- function(a) {
  sort(unique(a$violations$subgroup[a$violations$monitored]))
}

test1_subgroups <- function(a) {
  v <- a$violations
  sort(unique(v$subgroup[v$monitored & v$chart == "X-bar" & v$test == 1]))
}

n_subgroups <- function(a) nrow(a$subgroups)

recent_cutoff <- function(a, w = 24) n_subgroups(a) - w

out_last_24h <- function(a) {
  v <- utils::tail(a$readings$temp_c, 96)
  any(v < SPEC[["low"]] | v > SPEC[["high"]], na.rm = TRUE)
}

soon <- function(a) is.finite(a$hours) && a$hours <= 12

# Is there a run of k consecutive flagged subgroups?
run_of <- function(idx, k) {
  if (length(idx) < k) return(FALSE)
  any(vapply(seq_len(length(idx) - k + 1), function(i) {
    all(diff(idx[i:(i + k - 1)]) == 1L)
  }, logical(1)))
}

# ---- the four rules ------------------------------------------------------------------------------

verdict <- function(a, red, amber) {
  if (!a$has_limits) return("gray")
  if (red) return("red")
  if (amber) return("amber")
  "green"
}

rule_current <- function(a) {
  verdict(a,
          red = out_last_24h(a) || length(test1_subgroups(a)) > 0,
          amber = length(flag_subgroups(a)) > 0 || isTRUE(a$cpk < 1) || soon(a))
}

rule_run2 <- function(a) {
  flags <- flag_subgroups(a)
  verdict(a,
          red = out_last_24h(a) || run_of(test1_subgroups(a), 2),
          amber = run_of(flags, 2) || length(flags) >= 3 || isTRUE(a$cpk < 1) || soon(a))
}

# A rule built on a window of the most recent w subgroups. count = FALSE asks for any
# flag in the window; count = TRUE asks for two flags, or two in a row.
window_run <- function(a, w, count = TRUE) {
  cut <- recent_cutoff(a, w)
  flags <- flag_subgroups(a)
  recent <- flags[flags > cut]
  t1 <- test1_subgroups(a)
  rec_t1 <- t1[t1 > cut]
  amber <- if (count) {
    run_of(recent, 2) || length(recent) >= 2
  } else {
    length(recent) > 0
  }
  verdict(a,
          red = out_last_24h(a) || run_of(rec_t1, 2),
          amber = amber || isTRUE(a$cpk < 1) || soon(a))
}

rule_last24 <- function(a) {
  window_run(a, 24, count = FALSE)
}

rule_rec_run <- function(a) {
  window_run(a, 24)
}

rule_rec_2d <- function(a) {
  window_run(a, 48)
}

RULES <- list(current = rule_current, run2 = rule_run2,
              last24 = rule_last24, rec_run = rule_rec_run, rec_2d = rule_rec_2d)

# ---- simulated populations -----------------------------------------------------------------------

series_healthy <- function() round(stats::rnorm(N_READ, 3.5, 0.15), 2)

series_drift <- function() {
  base <- stats::rnorm(192, 3.5, 0.15)
  ramp <- stats::rnorm(N_READ - 192, 3.5 + seq_len(N_READ - 192) / (N_READ - 192) * 3.0, 0.15)
  round(c(base, ramp), 2)
}

series_step <- function() {
  c(stats::rnorm(192, 3.5, 0.15), stats::rnorm(N_READ - 192, 5.0, 0.3)) |> round(2)
}

POPULATIONS <- list(healthy = series_healthy, drift = series_drift, step = series_step)

as_analysis <- function(values) {
  a <- analyze_fridge("FX", data.frame(
    fridge_id = "FX",
    timestamp = as.POSIXct("2026-10-01 00:00:00", tz = "UTC") + (seq_along(values) - 1) * 900,
    temp_c = values
  ), blood_units = 0)
  a
}

simulate <- function(generator, n, seed) {
  set.seed(seed)
  lapply(seq_len(n), function(i) as_analysis(generator()))
}

# ---- the committed readings files ------------------------------------------------------------------

scenario_dirs <- c(
  demo = if (file.exists("data/readings.csv")) "data" else "../data",
  scenario_one_bad = NA_character_,
  scenario_one_good = NA_character_
)
root <- scenario_dirs[["demo"]]
scenario_dirs[["scenario_one_bad"]] <- file.path(root, "scenario_one_bad")
scenario_dirs[["scenario_one_good"]] <- file.path(root, "scenario_one_good")

file_analyses <- lapply(scenario_dirs, function(d) {
  dat <- load_demo_data(d)
  a <- analyze_all(dat$readings, dat$inventory)
  a[order(names(a))]
})

# ---- report -------------------------------------------------------------------------------------

cat("alert_rate.R - the badge under five aggregation rules\n")
cat("simulated fridges per population:", N_SIM, "| seed:", SEED,
    "| readings each:", N_READ, "| spec:", SPEC[["low"]], "to", SPEC[["high"]], "C\n\n")

cat("1. FALSE ALARMS - simulated populations (percent of fridges by verdict)\n\n")
for (pop in names(POPULATIONS)) {
  analyses <- simulate(POPULATIONS[[pop]], N_SIM, SEED)
  cat("  ", pop, "\n", sep = "")
  cat(sprintf("    %-9s %6s %6s %6s %10s %10s\n",
              "rule", "red%", "amber%", "green%", "red+amber%", "mean flags"))
  for (r in names(RULES)) {
    v <- vapply(analyses, RULES[[r]], character(1))
    flags <- vapply(analyses, function(a) length(flag_subgroups(a)), 0)
    cat(sprintf("    %-9s %6.1f %6.1f %6.1f %10.1f %10.2f\n", r,
                100 * mean(v == "red"), 100 * mean(v == "amber"), 100 * mean(v == "green"),
                100 * mean(v %in% c("red", "amber")), mean(flags)))
  }
  cat("\n")
}

cat("2. THE COMMITTED FILES - what each rule says about each fridge\n\n")
for (d in names(file_analyses)) {
  a <- file_analyses[[d]]
  cat("  ", d, "\n", sep = "")
  cat(sprintf("    %-9s %s\n", "rule", paste(sprintf("%-6s", names(a)), collapse = "")))
  for (r in names(RULES)) {
    v <- vapply(a, RULES[[r]], character(1))
    cat(sprintf("    %-9s %s   needing action: %d of %d\n", r,
                paste(sprintf("%-6s", v), collapse = ""),
                sum(v %in% c("red", "amber")), length(v)))
  }
  cat(sprintf("    %-9s %s\n", "cpk", paste(sprintf("%-6.2f", vapply(a, function(x) x$cpk, 0)), collapse = "")))
  cat("\n")
}

cat("3. SELF-CHECK - does the script's copy of the shipped rule agree with analyze_fridge()?\n\n")
ok <- TRUE
for (d in names(file_analyses)) {
  for (nm in names(file_analyses[[d]])) {
    a <- file_analyses[[d]][[nm]]
    same <- identical(rule_current(a), a$status)
    if (!same) {
      ok <- FALSE
      cat("    MISMATCH", d, nm, ": script says", rule_current(a), "app says", a$status, "\n")
    }
  }
}
cat(if (ok) "    every fridge agrees with the shipped badge\n" else "    see mismatches above\n", "\n")

cat("4. WHAT THE RULES SHARE, AND WHAT THE WINDOW COSTS\n\n")
cat("  Every rule keeps Cpk < 1 and a forecast of 12 hours or less as amber, so the\n")
cat("  slow problems stay visible: F02 of scenario_one_good (Cpk 0.537, nothing out of\n")
cat("  range) is amber and F06 (readings above 6 C) is red under all five rules.\n\n")
cat("  The window is what the day-long rules buy and what they cost. In the demo file\n")
cat("  F04's planted blackout runs on 2026-10-06 14:00 to 16:00, more than a day before\n")
cat("  the last reading, so last24 and rec_run drop F04 to green while rec_2d keeps it\n")
cat("  red. A resolved incident one to two days old is the case to argue about: the\n")
cat("  shipped rule already calls F04's bags not at risk (units_at_risk uses the same\n")
cat("  24-hour window), so rec_run makes the badge and the bag count agree.\n")
