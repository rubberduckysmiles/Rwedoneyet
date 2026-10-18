# Which special-cause tests actually fire on the demo data? Read-only.
# Kept out of tests/ on purpose: it prints, it asserts nothing, and it is a
# question we asked once ("which of the eight do we actually see?").
source("app/qc.R")
loaded <- load_demo_data("data")
analyses <- analyze_all(loaded$readings, loaded$inventory)
for (one in analyses) {
  v <- one$violations
  v <- v[v$monitored, , drop = FALSE]
  if (nrow(v) == 0) {
    cat(one$fridge_id, ": (nothing fired after baseline)\n")
  } else {
    key <- paste0(v$chart, " test ", v$test)
    tab <- table(key)
    cat(one$fridge_id, ":", paste(sprintf("%s x%d", names(tab), as.integer(tab)), collapse = ", "), "\n")
  }
}
all_v <- do.call(rbind, lapply(analyses, function(a) a$violations[a$violations$monitored, , drop = FALSE]))
cat("\nAll flags after baseline, by test:\n")
print(table(paste0(all_v$chart, " test ", all_v$test)))
