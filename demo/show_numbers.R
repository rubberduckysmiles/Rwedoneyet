# Print the ColdChain Monitor numbers for the three demo CSVs.
# From the repo root:  Rscript demo/show_numbers.R
# A teammate should see the same lines as demo/README.md.

source("app/qc.R")
loaded <- load_demo_data("data")
analyses <- analyze_all(loaded$readings, loaded$inventory)
summary_numbers <- overview_summary(analyses, loaded$generator)
generator <- generator_analysis(loaded$generator)

cat("Overview\n")
cat("  fridges needing action: ", summary_numbers$needing_action, "\n", sep = "")
cat("  blood units at risk: ", summary_numbers$units_at_risk, "\n", sep = "")
cat("  average Ppk: ", sprintf("%.3f", summary_numbers$average_ppk), "\n", sep = "")
cat("  last generator transfer: ", summary_numbers$last_transfer, " seconds\n", sep = "")
cat("\nFridges, highest risk first\n")
for (one in analyses) {
  cat(sprintf(
    "  %s  %s  bags=%g  at_risk=%g  Ppk=%.3f  Cpk=%.3f  hours=%s  RPN=%g  %s\n",
    one$fridge_id, one$status, one$blood_units, one$units_at_risk,
    one$ppk, one$cpk, one$hours_text, one$rpn, one$capable_sentence
  ))
}
cat("\nGenerator individuals chart\n")
cat(sprintf(
  "  n=%d  center=%.3f  lower=%.3f  upper=%.3f  2026-10-06 transfer=%s seconds\n",
  generator$n, generator$limits$center, generator$limits$lcl, generator$limits$ucl,
  loaded$generator$transfer_time_sec[loaded$generator$date == "2026-10-06"]
))
cat("DEMO OK\n")
