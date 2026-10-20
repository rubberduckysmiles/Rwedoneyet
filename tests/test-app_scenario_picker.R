library(testthat)

source(if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R")

# Source app.R for the DATASETS mapping (it only defines objects, it does not run).
old_wd <- getwd()
setwd(if (file.exists("app/app.R")) "." else "..")
local_app <- new.env(parent = globalenv())
source("app/app.R", local = local_app)
setwd(old_wd)
DATASETS <- local_app$DATASETS

data_dir <- if (file.exists("data/readings.csv")) "data" else "../data"
app_data_dir <- if (file.exists("app/data/readings.csv")) "app/data" else "../app/data"

test_that("DATASETS covers exactly the three folders and each resolves", {
  expect_equal(sort(names(DATASETS)), sort(c("general", "scenario_one_good", "scenario_one_bad")))
  for (id in names(DATASETS)) {
    folder <- file.path(data_dir, DATASETS[[id]])
    expect_true(dir.exists(folder), info = folder)
  }
})

for (id in c("general", "scenario_one_good", "scenario_one_bad")) {
  test_that(paste("load_demo_data works for", id), {
    folder <- file.path(data_dir, DATASETS[[id]])
    d <- load_demo_data(folder)
    expect_false(is.null(d$readings))
    expect_false(is.null(d$inventory))
    expect_false(is.null(d$generator))
    a <- analyze_all(d$readings, d$inventory)
    expect_length(a, 6L)
    expect_equal(sort(names(a)), paste0("F0", 1:6))
  })
}

test_that("app/data mirrors data/ byte for byte", {
  files <- list.files(app_data_dir, recursive = TRUE, full.names = FALSE)
  expect_gt(length(files), 0L)
  for (f in files) {
    a <- readBin(file.path(app_data_dir, f), "raw", file.info(file.path(app_data_dir, f))$size)
    b <- readBin(file.path(data_dir, f), "raw", file.info(file.path(data_dir, f))$size)
    expect_identical(a, b, info = f)
  }
})