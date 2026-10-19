# make_scenarios.R - generates two additional readings.csv variants for the ColdChain Monitor.
# Run from the repo root:  Rscript data/make_scenarios.R
# Outputs:
#   data/scenario_one_bad/readings.csv   (5 healthy fridges + 1 failing fridge)
#   data/scenario_one_good/readings.csv  (1 healthy fridge + 5 failing fridges, each a different failure mode)
# Inventory and generator log are copied from data/ (unchanged).

set.seed(5300)

ts <- seq(as.POSIXct("2026-10-01 00:00:00", tz = "UTC"),
          as.POSIXct("2026-10-07 23:45:00", tz = "UTC"),
          by = 15 * 60)
stopifnot(length(ts) == 672)
ts_chr <- format(ts, "%Y-%m-%d %H:%M:%S", tz = "UTC")
n <- length(ts)

baseline_end <- as.POSIXct("2026-10-02 23:45:00", tz = "UTC")
drift_start <- as.POSIXct("2026-10-03 00:00:00", tz = "UTC")

at <- function(x) match(x, ts_chr)

common_cause <- function() round(rnorm(n, mean = 3.5, sd = 0.15), 2)

make_fridge <- function(id, temp_c, door_open = rep(0L, n), on_generator = rep(0L, n)) {
  data.frame(fridge_id = id, timestamp = ts_chr, temp_c = temp_c,
             door_open = as.integer(door_open), on_generator = as.integer(on_generator),
             stringsAsFactors = FALSE)
}

# Failure-mode builders (each returns a list with temp_c, door_open, on_generator)
mode_healthy <- function() list(temp = common_cause(), door = rep(0L, n), gen = rep(0L, n))
mode_drift <- function() list(temp = round(rnorm(n, mean = 3.5 + 0.035 * pmax(0, as.numeric(difftime(ts, drift_start, units = "hours"))), sd = 0.15), 2),
                             door = rep(0L, n), gen = rep(0L, n))
mode_door <- function() {
  t <- common_cause(); d <- rep(0L, n)
  spikes <- c("2026-10-04 08:00:00" = 7.50, "2026-10-04 08:15:00" = 6.80,
              "2026-10-05 12:00:00" = 7.20, "2026-10-05 12:15:00" = 6.40,
              "2026-10-06 18:00:00" = 7.80, "2026-10-06 18:15:00" = 6.60,
              "2026-10-07 09:00:00" = 7.40, "2026-10-07 09:15:00" = 6.50)
  for (k in seq_along(spikes)) { i <- at(names(spikes)[k]); t[i] <- spikes[[k]]; d[i] <- 1L }
  list(temp = t, door = d, gen = rep(0L, n))
}
mode_blackout <- function() {
  t <- common_cause(); g <- rep(0L, n)
  bt <- c("2026-10-06 14:00:00","2026-10-06 14:15:00","2026-10-06 14:30:00",
          "2026-10-06 14:45:00","2026-10-06 15:00:00","2026-10-06 15:15:00",
          "2026-10-06 15:30:00","2026-10-06 15:45:00","2026-10-06 16:00:00")
  btemp <- c(4.80,5.60,6.50,7.40,6.80,5.70,4.80,4.10,3.70)
  bgen <- c(0L,0L,0L,1L,1L,1L,1L,1L,0L)
  for (k in seq_along(bt)) { i <- at(bt[k]); t[i] <- btemp[k]; g[i] <- bgen[k] }
  list(temp = t, door = rep(0L, n), gen = g)
}
mode_flatline <- function() {
  t <- common_cause()
  stuck <- ts >= as.POSIXct("2026-10-04 00:00:00", tz = "UTC") &
           ts <= as.POSIXct("2026-10-05 11:45:00", tz = "UTC")
  t[stuck] <- 3.50
  list(temp = t, door = rep(0L, n), gen = rep(0L, n))
}

build_readings <- function(modes) {
  # modes: named list fridge_id -> mode function
  frames <- lapply(names(modes), function(id) {
    m <- modes[[id]]()
    make_fridge(id, m$temp, door_open = m$door, on_generator = m$gen)
  })
  out <- do.call(rbind, frames)
  out$temp_c <- sprintf("%.2f", out$temp_c)
  out
}

# Scenario 1: only one non-functioning fridge (F06 drifts), rest healthy.
modes_one_bad <- list(
  F01 = mode_healthy, F02 = mode_healthy, F03 = mode_healthy,
  F04 = mode_healthy, F05 = mode_healthy, F06 = mode_drift
)
r1 <- build_readings(modes_one_bad)
dir.create("data/scenario_one_bad", showWarnings = FALSE, recursive = TRUE)
write.csv(r1, "data/scenario_one_bad/readings.csv", row.names = FALSE, quote = FALSE)

# Scenario 2: only one functioning (F01 healthy), rest show different failures.
modes_one_good <- list(
  F01 = mode_healthy,
  F02 = mode_drift,
  F03 = mode_door,
  F04 = mode_blackout,
  F05 = mode_flatline,
  F06 = mode_healthy  # keep F06 healthy too? spec says only 1 functioning. Make F06 a second drift? 
)
# To have exactly one functioning, make F06 also a failure (defrost-healthy is still healthy-ish).
# Use door-spike-less variant: make F06 a drift with different rate is still "drift". Instead make
# F06 a flatline-ish? Simpler: keep 5 distinct failures by reusing modes but ensure 5 non-healthy.
# We already have 4 distinct (drift, door, blackout, flatline). Add defrost as a 5th healthy-ish?
# The codebook treats F06 defrost as healthy. So to have only 1 functioning, replace F06 with drift2.
modes_one_good$F06 <- mode_drift
r2 <- build_readings(modes_one_good)
dir.create("data/scenario_one_good", showWarnings = FALSE, recursive = TRUE)
write.csv(r2, "data/scenario_one_good/readings.csv", row.names = FALSE, quote = FALSE)

# Copy inventory and generator log into both scenario folders.
for (d in c("data/scenario_one_bad", "data/scenario_one_good")) {
  file.copy("data/inventory.csv", file.path(d, "inventory.csv"), overwrite = TRUE)
  file.copy("data/generator_log.csv", file.path(d, "generator_log.csv"), overwrite = TRUE)
}

cat("Wrote scenario CSVs.\n")
