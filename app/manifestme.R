# Write app/manifest.json for Posit Connect.
# From the repo root:  Rscript app/manifestme.R
# Run this on your own machine after a package change. Do not run it in GitHub Actions.
#
# The manifest is a fingerprint of the machine that writes it, so it pins the R
# version the Connect server runs. app/manifest.json says "platform": "4.5.2".
# If this machine runs a different R, writeManifest() records THIS machine's R
# instead and the published bundle moves off 4.5.2, re-deriving every package
# version with it. This script checks for that and refuses.
#
# On purpose, after reading the diff:  ALLOW_PLATFORM_CHANGE=1 Rscript app/manifestme.R
if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop("Install the rsconnect package, then run this again.")
}

running <- paste(R.version$major, R.version$minor, sep = ".")
manifest_path <- "app/manifest.json"

# The platform the committed manifest pins, or NA when there is no manifest yet.
committed_platform <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  line <- grep('"platform"[[:space:]]*:', readLines(path, warn = FALSE), value = TRUE)
  if (length(line) == 0) return(NA_character_)
  sub('.*"platform"[[:space:]]*:[[:space:]]*"([^"]+)".*', "\\1", line[1])
}

pinned <- committed_platform(manifest_path)
override <- identical(Sys.getenv("ALLOW_PLATFORM_CHANGE"), "1")

if (!is.na(pinned) && !identical(pinned, running) && !override) {
  stop(paste0(
    "This machine runs R ", running, " but ", manifest_path, " pins platform ", pinned,
    ", the R on the Connect server.\n",
    "writeManifest() would rewrite the platform to ", running,
    " and re-derive every package version, moving the live app off ", pinned, ".\n",
    "Run this on an R ", pinned, " machine, or set ALLOW_PLATFORM_CHANGE=1 to do it on purpose."
  ), call. = FALSE)
}

r_files <- list.files("app/R", pattern = "\\.[Rr]$", full.names = FALSE)
data_files <- list.files("app/data", pattern = "\\.csv$", full.names = FALSE)
app_files <- c("app.R", "qc.R", file.path("R", r_files), file.path("data", data_files))

rsconnect::writeManifest(appDir = "app", appFiles = app_files)
cat("Wrote app/manifest.json at platform", running,
    if (is.na(pinned)) "(no platform was pinned before)" else paste0("(was ", pinned, ")"), "\n")
