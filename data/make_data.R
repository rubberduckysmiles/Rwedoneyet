# make_data.R - the ONLY generator for the three CSVs in data/.
# All data are SYNTHETIC (invented). Run from the repo root:  Rscript data/make_data.R
set.seed(5300)

# ---- Time grid: every 15 minutes, 2026-10-01 00:00:00 to 2026-10-07 23:45:00 (672 rows) ----
ts <- seq(as.POSIXct("2026-10-01 00:00:00", tz = "UTC"),
          as.POSIXct("2026-10-07 23:45:00", tz = "UTC"),
          by = 15 * 60)
stopifnot(length(ts) == 672)
ts_chr <- format(ts, "%Y-%m-%d %H:%M:%S", tz = "UTC")  # the text stored in the CSV
n <- length(ts)

# The first 48 hours are the baseline: common-cause noise only, no planted failure.
baseline_end <- as.POSIXct("2026-10-02 23:45:00", tz = "UTC")
is_baseline <- ts <= baseline_end
drift_start <- as.POSIXct("2026-10-03 00:00:00", tz = "UTC")

# Row index for a clock time (used to plant the scenarios).
at <- function(x) {
  i <- match(x, ts_chr)
  stopifnot(!is.na(i))
  i
}

# Common-cause noise: mean 3.5 C, sd 0.15 C, rounded to 2 decimals like a probe.
common_cause <- function() round(rnorm(n, mean = 3.5, sd = 0.15), 2)

make_fridge <- function(id, temp_c, door_open = rep(0L, n), on_generator = rep(0L, n)) {
  data.frame(fridge_id = id, timestamp = ts_chr, temp_c = temp_c,
             door_open = as.integer(door_open), on_generator = as.integer(on_generator),
             stringsAsFactors = FALSE)
}

# ---- F01: healthy. Noise all week. ----
f01 <- make_fridge("F01", common_cause())

# ---- F02: drifting compressor. +0.035 C per hour from 2026-10-03 00:00:00. ----
hours_drift <- pmax(0, as.numeric(difftime(ts, drift_start, units = "hours")))
f02 <- make_fridge("F02", round(rnorm(n, mean = 3.5 + 0.035 * hours_drift, sd = 0.15), 2))

# ---- F03: door-open spikes (value replaces the random draw). ----
t03 <- common_cause()
d03 <- rep(0L, n)
spikes <- c("2026-10-04 08:00:00" = 7.50, "2026-10-04 08:15:00" = 6.80,
            "2026-10-05 12:00:00" = 7.20, "2026-10-05 12:15:00" = 6.40,
            "2026-10-06 18:00:00" = 7.80, "2026-10-06 18:15:00" = 6.60,
            "2026-10-07 09:00:00" = 7.40, "2026-10-07 09:15:00" = 6.50)
for (k in seq_along(spikes)) {
  i <- at(names(spikes)[k])
  t03[i] <- spikes[[k]]
  d03[i] <- 1L
}
f03 <- make_fridge("F03", t03, door_open = d03)

# ---- F04: blackout on 2026-10-06 from 14:00, slow generator (nine rows replace the draw). ----
t04 <- common_cause()
g04 <- rep(0L, n)
blackout_times <- c("2026-10-06 14:00:00", "2026-10-06 14:15:00", "2026-10-06 14:30:00",
                    "2026-10-06 14:45:00", "2026-10-06 15:00:00", "2026-10-06 15:15:00",
                    "2026-10-06 15:30:00", "2026-10-06 15:45:00", "2026-10-06 16:00:00")
blackout_temp <- c(4.80, 5.60, 6.50, 7.40, 6.80, 5.70, 4.80, 4.10, 3.70)
blackout_gen  <- c(0L,   0L,   0L,   1L,   1L,   1L,   1L,   1L,   0L)
for (k in seq_along(blackout_times)) {
  i <- at(blackout_times[k])
  t04[i] <- blackout_temp[k]
  g04[i] <- blackout_gen[k]
}
f04 <- make_fridge("F04", t04, on_generator = g04)

# ---- F05: flatlined sensor, exactly 3.50 from 10-04 00:00:00 through 10-05 11:45:00. ----
t05 <- common_cause()
stuck <- ts >= as.POSIXct("2026-10-04 00:00:00", tz = "UTC") &
         ts <= as.POSIXct("2026-10-05 11:45:00", tz = "UTC")
t05[stuck] <- 3.50
f05 <- make_fridge("F05", t05)

# ---- F06: healthy, with a normal defrost: the 02:00:00 reading each day is draw + 0.40 C. ----
t06 <- common_cause()
defrost <- format(ts, "%H:%M:%S", tz = "UTC") == "02:00:00"
stopifnot(sum(defrost) == 7)
t06[defrost] <- round(t06[defrost] + 0.40, 2)
f06 <- make_fridge("F06", t06)

# ---- readings.csv ----
readings <- rbind(f01, f02, f03, f04, f05, f06)
stopifnot(nrow(readings) == 4032)
out <- readings
out$temp_c <- sprintf("%.2f", out$temp_c)  # always 2 decimals, e.g. 3.50
write.csv(out, "data/readings.csv", row.names = FALSE, quote = FALSE)

# ---- inventory.csv: count of red-cell bags per fridge ----
inventory <- data.frame(fridge_id = c("F01", "F02", "F03", "F04", "F05", "F06"),
                        blood_units = c(12L, 180L, 40L, 220L, 8L, 55L))
write.csv(inventory, "data/inventory.csv", row.names = FALSE, quote = FALSE)

# ---- generator_log.csv: 30 daily transfer tests, 2026-09-07 to 2026-10-06 ----
dates <- seq(as.Date("2026-09-07"), as.Date("2026-10-06"), by = "day")
stopifnot(length(dates) == 30)
draw_ok <- function() {
  repeat {  # redraw until the ordinary day is inside 3-9 seconds
    x <- round(rnorm(1, mean = 6, sd = 1), 1)
    if (x >= 3 && x <= 9) return(x)
  }
}
transfer <- numeric(30)
for (k in 1:29) transfer[k] <- draw_ok()
transfer[30] <- 48.0  # 2026-10-06: the F04 blackout, slow generator
gen <- data.frame(date = format(dates, "%Y-%m-%d"), transfer_time_sec = sprintf("%.1f", transfer))
write.csv(gen, "data/generator_log.csv", row.names = FALSE, quote = FALSE)

cat("Wrote data/readings.csv, data/inventory.csv, data/generator_log.csv (seed 5300)\n")
