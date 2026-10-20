# Publish Bank of Bloody Mary to the course Posit Connect server, from this machine.
#
#   Rscript app/deployme.R          # run from the repo root
#
# This is the fast first deploy, and the fallback when the GitHub Actions deploy
# (.github/workflows/deploy-shiny-r.yml) is red. Actions stays the main path: it
# publishes the committed manifest on every push to main, and it will overwrite
# whatever this script publishes.
#
# Credentials come from the environment and are never written to a file:
#
#   CONNECT_SERVER    e.g. https://connect.systems-apps.com
#   CONNECT_API_KEY   the publisher key handed out at the event
#
# Put them in the gitignored .env at the repo root (that is what the
# connect-publish skill recommends), or export them for one run. They are the
# same two names the Actions workflow reads from the repo secrets. Never commit
# either one.
#
# The bundle is app/ exactly as app/manifest.json describes it. Re-run
#   Rscript app/manifestme.R
# first if any app file changed.

if (!file.exists("app/app.R")) {
  stop("Run this from the repo root: Rscript app/deployme.R", call. = FALSE)
}
if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop("Install the rsconnect package first: install.packages('rsconnect')", call. = FALSE)
}
if (!file.exists("app/manifest.json")) {
  stop("app/manifest.json is missing. Run Rscript app/manifestme.R, then commit it.", call. = FALSE)
}

# Load the two credentials out of the gitignored .env, if there is one, without
# printing anything. Values already in the environment win.
if (file.exists(".env")) {
  for (line in readLines(".env", warn = FALSE)) {
    line <- trimws(line)
    if (!nzchar(line) || startsWith(line, "#")) next
    parts <- strsplit(line, "=", fixed = TRUE)[[1]]
    if (length(parts) < 2) next
    key <- trimws(parts[1])
    value <- gsub('^["\']|["\']$', "", trimws(paste(parts[-1], collapse = "=")))
    if (key %in% c("CONNECT_SERVER", "CONNECT_API_KEY") && !nzchar(Sys.getenv(key))) {
      do.call(Sys.setenv, stats::setNames(list(value), key))
    }
  }
}

needed <- c("CONNECT_SERVER", "CONNECT_API_KEY")
missing <- needed[!nzchar(Sys.getenv(needed))]
if (length(missing) > 0) {
  stop("Missing ", paste(missing, collapse = " and "),
       ". Set them in your environment or in a gitignored .env and run this again. ",
       "They are the same two names the GitHub Actions deploy uses. ",
       "Never put either value in a file that is committed.", call. = FALSE)
}

server_url <- sub("/+$", "", Sys.getenv("CONNECT_SERVER"))
server_name <- "hackathon-connect"
account <- "publisher"

# One named server, so a second run does not ask again. The key goes to
# rsconnect's own credential store; it is never written into this repo.
rsconnect::addServer(url = server_url, name = server_name)
rsconnect::connectApiUser(account = account, server = server_name,
                          apiKey = Sys.getenv("CONNECT_API_KEY"))

# The same file list app/manifestme.R pins, so a local bundle and a CI bundle
# carry the same files.
app_files <- c(
  "app.R", "qc.R",
  file.path("R", list.files("app/R", pattern = "\\.[Rr]$")),
  file.path("data", list.files("app/data", pattern = "\\.csv$", recursive = TRUE))
)

deployed <- rsconnect::deployApp(
  appDir = "app",
  appFiles = app_files,
  appName = "rubberduckysmiles-Rwedoneyet-shiny",
  server = server_name,
  account = account,
  launch.browser = FALSE,
  forceUpdate = TRUE
)

cat("Published", deployed$appName, "to", server_url, "\n")
if (!is.null(deployed$url)) cat("URL:", deployed$url, "\n")
cat("The next push to main redeploys this content from GitHub Actions.\n")
