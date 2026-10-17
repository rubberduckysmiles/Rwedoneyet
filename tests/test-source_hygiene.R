source(if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R") # works from the repo root and from inside tests/
library(testthat)

# Team rules: a banned name must not appear anywhere in code, comments, tests or messages.
# The banned words are built from pieces so that this file does not contain them itself.
app_dir <- if (file.exists("app/qc.R")) "app" else "../app"
tests_dir <- if (file.exists("app/qc.R")) "tests" else "."

r_files <- function() {
  c(
    list.files(app_dir, pattern = "\\.[Rr]$", recursive = TRUE, full.names = TRUE),
    list.files(tests_dir, pattern = "\\.[Rr]$", recursive = TRUE, full.names = TRUE)
  )
}

test_that("a named person's rule set is not mentioned anywhere under app/ or tests/", {
  banned <- paste0("Nel", "son")
  files <- r_files()
  expect_gt(length(files), 0)
  for (f in files) {
    txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
    expect_false(grepl(banned, txt, ignore.case = TRUE), info = f)
  }
})

test_that("the statistics do not use a packaged control-chart library", {
  files <- r_files()
  pkg <- paste0("qc", "c")
  for (f in files) {
    txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
    expect_false(grepl(paste0("library\\(", pkg, "\\)|", pkg, "::|require\\(", pkg, "\\)"), txt), info = f)
  }
})

test_that("no looked-up chart constant table is used: the constants are computed", {
  # Computing d2 means range_constants() must call ptukey.
  txt <- paste(readLines(file.path(app_dir, "R", "range_constants.R"), warn = FALSE), collapse = "\n")
  expect_true(grepl("ptukey", txt))
})

test_that("app/qc.R holds no statistics, only source() calls", {
  lines <- readLines(file.path(app_dir, "qc.R"), warn = FALSE)
  code <- trimws(lines[!grepl("^\\s*#", lines)])
  code <- code[nzchar(code)]
  expect_false(any(grepl("\\bmean\\(|\\bsd\\(|\\bvar\\(|sqrt\\(|ptukey", code)))
})

test_that("there are no money amounts in the code, comments or messages", {
  words <- paste0(paste0("doll", "ar"), "|", paste0("US", "D"))
  for (f in r_files()) {
    txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
    expect_false(grepl(words, txt, ignore.case = TRUE), info = f)
    expect_false(grepl("[$][0-9]", txt), info = f)
  }
})
