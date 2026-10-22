# H-46: the two example datasets are shown as "Dataset 1" and "Dataset 2".
#
# The names a manager reads are the dropdown labels. They used to be
# "Scenario one: good" and "Scenario one: bad", which named the folder rather
# than saying anything about the data. They are now "Dataset 1" and "Dataset 2",
# and the help text beside them has to carry the meaning the old names carried,
# or the dropdown offers two names the caption never mentions.
#
# The ids and folders deliberately do NOT move: scenario_one_good is still the
# id and still the folder, so these tests also pin that the rename is cosmetic
# - switching to "Dataset 1" must still load the same eight CSV files and reach
# the same numbers.
library(testthat)

path <- if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R"
source(path)

data_dir <- if (file.exists("data/readings.csv")) "data" else "../data"
app_dir <- if (file.exists("app/app.R")) "app" else "../app"

app_exprs <- parse(file.path(app_dir, "app.R"))
is_launch <- function(e) is.call(e) && identical(as.character(e[[1]]), "shinyApp")
env <- new.env(parent = globalenv())
old_wd <- setwd(app_dir)
for (e in app_exprs[!vapply(app_exprs, is_launch, logical(1))]) eval(e, envir = env)
setwd(old_wd)

demo <- load_demo_data(data_dir)
all_analyses <- analyze_all(demo$readings, demo$inventory)

test_that("the labels are exactly Dataset 1 and Dataset 2, and General is unchanged", {
  labels <- unname(env$DATASET_LABELS[names(env$DATASETS)])
  expect_setequal(labels, c("General demo (planted failures)", "Dataset 1", "Dataset 2"))
  # 1 is the good folder, 2 is the bad folder: the mapping the team asked for.
  expect_equal(unname(env$DATASET_LABELS["scenario_one_good"]), "Dataset 1")
  expect_equal(unname(env$DATASET_LABELS["scenario_one_bad"]), "Dataset 2")
})

test_that("the old names are gone from every label and help line", {
  # The request was a rename, not an addition, so nothing user-facing may still
  # say "Scenario one". A leftover label would be the silent half-failure.
  labels <- paste(unname(env$DATASET_LABELS), collapse = " | ")
  expect_false(grepl("Scenario one", labels, fixed = TRUE))
  expect_false(grepl("scenario one", labels, fixed = TRUE))
  for (txt in c(env$DATASET_HELP, env$DATASET_HELP_SHORT)) {
    expect_false(grepl("Scenario one", txt, fixed = TRUE))
  }
})

test_that("the help text names the new labels, so the caption matches the dropdown", {
  # This is the trap the rename creates. The old help text said "Good is the
  # mixed set. Bad is ordinary noise." Those words are the labels' replacements,
  # so once the labels change the help must name "Dataset 1" and "Dataset 2" or
  # the caption explains nothing the manager can see.
  expect_match(env$DATASET_HELP, "Dataset 1", fixed = TRUE)
  expect_match(env$DATASET_HELP, "Dataset 2", fixed = TRUE)
  expect_match(env$DATASET_HELP_SHORT, "Dataset 1", fixed = TRUE)
  expect_match(env$DATASET_HELP_SHORT, "Dataset 2", fixed = TRUE)

  # And it must still say which is which, not just name them.
  expect_match(env$DATASET_HELP_SHORT, "mixed set", fixed = TRUE)
  expect_match(env$DATASET_HELP_SHORT, "ordinary noise", fixed = TRUE)
})

test_that("both real pickers offer the new labels through the server", {
  shiny::testServer(env$server, {
    session$setInputs(fridge = "F01", color_mode = "light")

    picker <- paste(unlist(output$overview_dataset_picker), collapse = " ")
    expect_match(picker, ">Dataset 1</option>", fixed = TRUE,
                 info = "the Overview dropdown shows Dataset 1")
    expect_match(picker, ">Dataset 2</option>", fixed = TRUE,
                 info = "the Overview dropdown shows Dataset 2")
    expect_match(picker, ">General demo (planted failures)</option>", fixed = TRUE)
    expect_false(grepl("Scenario one", picker, fixed = TRUE),
                 info = "no old name survives in the rendered dropdown")
  })

  # The Data page picker is a static selectInput in the UI, so it is read from
  # the UI rather than from a render function. It shares DATASET_CHOICES with
  # the Overview dropdown, so the two cannot disagree.
  ui_html <- as.character(env$ui)
  expect_match(ui_html, ">Dataset 1</option>", fixed = TRUE,
               info = "the Data page picker shows Dataset 1")
  expect_match(ui_html, ">Dataset 2</option>", fixed = TRUE,
               info = "the Data page picker shows Dataset 2")
  expect_false(grepl("Scenario one", ui_html, fixed = TRUE),
               info = "no old name survives anywhere in the UI")
})

test_that("the Overview card's one line still tells a manager which is which", {
  shiny::testServer(env$server, {
    session$setInputs(fridge = "F01", color_mode = "light")
    picker <- paste(unlist(output$overview_dataset_picker), collapse = " ")
    expect_match(picker, env$DATASET_HELP_SHORT, fixed = TRUE)
    # Renaming must not shorten the card into a bare list of two names.
    expect_match(picker, "mixed set", fixed = TRUE)
    expect_match(picker, "ordinary noise", fixed = TRUE)
  })
})

test_that("the rename is cosmetic: Dataset 1 still loads scenario_one_good", {
  # The ids and folders stayed, so the numbers behind the new names are the same
  # numbers as before. If someone had renamed the folders too, this would fail.
  expect_equal(unname(env$DATASETS[["scenario_one_good"]]), "scenario_one_good")
  expect_equal(unname(env$DATASETS[["scenario_one_bad"]]), "scenario_one_bad")
  expect_true(dir.exists(file.path(data_dir, "scenario_one_good")))
  expect_true(dir.exists(file.path(data_dir, "scenario_one_bad")))

  shiny::testServer(env$server, {
    session$setInputs(fridge = "F01", color_mode = "light")

    session$setInputs(overview_dataset = "scenario_one_good")
    expect_equal(overview_dataset_id(), "scenario_one_good")
    expect_equal(summary_numbers()$units_at_risk, 67)

    session$setInputs(overview_dataset = "scenario_one_bad")
    expect_equal(overview_dataset_id(), "scenario_one_bad")
    expect_equal(summary_numbers()$units_at_risk, 275)
  })
})

test_that("the Data page lines the three Browse controls up", {
  # The readings label wraps onto a second line. The row class stretches each
  # picker and pushes its Browse control to the bottom of that row.
  ui_html <- as.character(env$ui)
  expect_match(ui_html, "bbm-uploads", fixed = TRUE)
  expect_match(ui_html, "up_readings", fixed = TRUE)
  expect_match(ui_html, "up_inventory", fixed = TRUE)
  expect_match(ui_html, "up_generator", fixed = TRUE)
})
