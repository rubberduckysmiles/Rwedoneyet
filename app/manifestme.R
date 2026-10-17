# Write app/manifest.json for Posit Connect.
# From the repo root:  Rscript app/manifestme.R
# Run this on your own machine after a package change. Do not run it in GitHub Actions.
if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop("Install the rsconnect package, then run this again.")
}
r_files <- list.files("app/R", pattern = "\\.[Rr]$", full.names = FALSE)
data_files <- list.files("app/data", pattern = "\\.csv$", full.names = FALSE)
app_files <- c("app.R", "qc.R", file.path("R", r_files), file.path("data", data_files))
rsconnect::writeManifest(appDir = "app", appFiles = app_files)
cat("Wrote app/manifest.json\n")
