# The numbers check. It finishes by itself and never starts Shiny.
# From the repo root:  Rscript app/workflow.R
source("app/qc.R")
source("tests/known_rows.R")

# 1. The 10-hour known-answer rows from SPEC.md section 4.
result <- freeze_baseline(stable_values, subgroup_n = 4, baseline_subgroups = 48, min_subgroups = 10)

got <- c(
  sigma_short = result$sigma_short,
  sigma_overall = result$sigma_overall,
  xbar_lcl = result$limits$xbar$lcl,
  xbar_ucl = result$limits$xbar$ucl,
  range_center = result$limits$range$center,
  range_ucl = result$limits$range$ucl,
  range_lcl = result$limits$range$lcl,
  cpk = result$capability$cpk,
  ppk = result$capability$ppk,
  gap = result$capability$gap,
  lag1 = result$lag1
)
want <- c(
  sigma_short = 0.2569046516,
  sigma_overall = 0.2253202849,
  xbar_lcl = 3.1146430226,
  xbar_ucl = 3.8853569774,
  range_center = 0.5289026431,
  range_ucl = 1.2069831025,
  range_lcl = 0,
  cpk = 3.2437456007,
  ppk = 3.6984390192,
  gap = -0.4546934185,
  lag1 = -0.2174115934
)

cat("Known-answer rows (SPEC.md section 4)\n")
for (name in names(got)) cat(sprintf("%-14s got %.10f   SPEC %.10f\n", name, got[[name]], want[[name]]))
for (name in names(want)) stopifnot(isTRUE(abs(got[[name]] - want[[name]]) < 1e-6))

# 2. Fridge F01 from data/readings.csv, through the same function the app uses.
readings <- read.csv("data/readings.csv", stringsAsFactors = FALSE)
f01 <- readings[readings$fridge_id == "F01", ]
f01 <- f01[order(as.POSIXct(f01$timestamp, tz = "UTC")), ]
app_result <- freeze_baseline(f01$temp_c, subgroup_n = 4, baseline_subgroups = 48, min_subgroups = 25)

cat("\nF01 through the app function\n")
cat(sprintf("F01 sigma_short %.6f\n", app_result$sigma_short))
cat(sprintf("F01 cpk         %.6f\n", app_result$capability$cpk))
cat(sprintf("F01 ppk         %.6f\n", app_result$capability$ppk))

cat("\nWORKFLOW OK\n")
