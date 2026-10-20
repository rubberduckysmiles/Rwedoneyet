# Formatting branch: the Overview dataset dropdown, the shared description card, and the
# blood-type chart colors.
#
# Three requested changes, each pinned here because each is the kind that fails silently:
#   1. the Overview dropdown must actually swap the loaded dataset on the FIRST pick
#      (an observer with ignoreInit = TRUE swallows exactly that one), and the Data page
#      picker must stay in sync with it;
#   2. the two paragraphs that used to repeat under all six fridge cards must live in the
#      single description card, and must not come back on the cards;
#   3. "At risk" must be red and "Within spec" green on every fridge, whatever its badge.
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

AT_RISK_RED <- "#D64045"
WITHIN_SPEC_GREEN <- "#2E9E6B"

# ------------------------------------------------------------ 3. chart colors

test_that("At risk is always red and Within spec is always green", {
  skip_if(nrow(demo$inventory) == 0, "no demo inventory")

  for (id in names(all_analyses)) {
    a <- all_analyses[[id]]
    bt <- bloodtype_table(demo$inventory, id, a$units_at_risk)
    skip_if(nrow(bt) == 0, paste("no inventory for", id))

    b <- plotly::plotly_build(env$bloodtype_plot(bt, dark = FALSE))
    names <- vapply(b$x$data, function(t) as.character(t$name)[1], character(1))
    colors <- vapply(b$x$data, function(t) as.character(t$marker$color)[1], character(1))
    by_name <- stats::setNames(colors, names)

    info <- sprintf("%s (badge %s)", id, a$status)
    expect_equal(unname(by_name[["At risk"]]), AT_RISK_RED, info = info)
    expect_equal(unname(by_name[["Within spec"]]), WITHIN_SPEC_GREEN, info = info)
  }
})

test_that("a green fridge no longer paints its at-risk bags green", {
  # The original defect: the at-risk bars took the fridge's status color, so a green
  # fridge drew at-risk bags in green - the one color that reads as safe.
  #
  # On the current demo both green fridges have zero at-risk bags, so the situation
  # cannot be observed from data alone. Build it instead: bloodtype_table() splits by the
  # fridge's own units_at_risk, so asking a green fridge for at-risk bags produces exactly
  # the case that used to fail. This is the fridge the manager would most easily misread.
  skip_if(nrow(demo$inventory) == 0, "no demo inventory")
  green <- names(all_analyses)[vapply(all_analyses,
                                      function(a) identical(a$status, "green"), logical(1))]
  skip_if(length(green) == 0, "no green fridge in the demo")

  id <- green[1]
  bt <- bloodtype_table(demo$inventory, id, all_analyses[[id]]$units_at_risk)
  skip_if(nrow(bt) == 0, "no inventory rows for the green fridge")

  # Force the at-risk split the defect needs, on the same rows the app uses.
  bt$units_at_risk <- bt$blood_units
  b <- plotly::plotly_build(env$bloodtype_plot(bt, dark = FALSE))
  names_ <- vapply(b$x$data, function(t) as.character(t$name)[1], character(1))
  colors <- vapply(b$x$data, function(t) as.character(t$marker$color)[1], character(1))
  by_name <- stats::setNames(colors, names_)

  expect_true(sum(bt$units_at_risk) > 0, info = "the case must really have at-risk bags")
  expect_equal(unname(by_name[["At risk"]]), AT_RISK_RED,
               info = "a green fridge's at-risk bags must still be red")
  expect_false(identical(unname(by_name[["At risk"]]), WITHIN_SPEC_GREEN),
               info = "at-risk bags must never be painted the safe green")
  expect_equal(unname(by_name[["Within spec"]]), WITHIN_SPEC_GREEN)
})

test_that("the blood-type plot takes no status color at all", {
  # The signature is the guarantee: with no status_color parameter, no caller can
  # reintroduce the coupling by passing one.
  expect_false("status_color" %in% names(formals(env$bloodtype_plot)))
  expect_setequal(names(formals(env$bloodtype_plot)), c("bt", "dark"))
})

# ------------------------------------------------------------ 2. description card

test_that("the shared explanations live in one card and not on every fridge card", {
  skip_if(length(all_analyses) == 0, "no demo readings")

  shiny::testServer(env$server, {
    session$setInputs(fridge = "F01", color_mode = "light")
    cards <- paste(unlist(output$fridge_cards), collapse = " ")
    notes <- paste(unlist(output$overview_notes), collapse = " ")

    expect_true(nchar(notes) > 0, info = "the description card must render")
    for (phrase in c("bags stored", "nearer of 1", "fitted line reaches", "first 48 hours")) {
      expect_match(notes, phrase, fixed = TRUE, info = paste("notes card:", phrase))
    }
    # The column list and the whole paragraph must not be repeated per card.
    expect_false(grepl("bags stored", cards, fixed = TRUE))
    expect_false(grepl("typical hour-to-hour spread", cards, fixed = TRUE))

    # The per-card sentence stays: it is genuinely per fridge.
    expect_true(grepl("No special-cause flag", cards, fixed = TRUE))
  })
})

test_that("the description card states the explanation once, not six times", {
  skip_if(length(all_analyses) == 0, "no demo readings")

  shiny::testServer(env$server, {
    session$setInputs(fridge = "F01", color_mode = "light")
    notes <- paste(unlist(output$overview_notes), collapse = " ")
    cards <- paste(unlist(output$fridge_cards), collapse = " ")

    # "bags stored" appears once in the notes and nowhere on the cards.
    expect_equal(lengths(regmatches(notes, gregexpr("bags stored", notes, fixed = TRUE))), 1L)
    expect_equal(lengths(regmatches(cards, gregexpr("bags stored", cards, fixed = TRUE))), 0L)
  })
})

# ------------------------------------------------------------ 1. dataset dropdown

test_that("the Overview dropdown swaps the dataset on the first pick", {
  # The regression this pins: ignoreInit = TRUE would drop the very first selection,
  # leaving the page showing the old dataset with no error and no sign anything failed.
  shiny::testServer(env$server, {
    expect_equal(overview_dataset_id(), "general")
    base_risk <- summary_numbers()$units_at_risk

    session$setInputs(overview_dataset = "scenario_one_good")
    expect_equal(overview_dataset_id(), "scenario_one_good")
    expect_false(identical(summary_numbers()$units_at_risk, base_risk),
                 info = "the numbers must change with the dataset, not stay put")
  })
})

test_that("the two dataset pickers stay in sync, either way round", {
  shiny::testServer(env$server, {
    # rv$dataset_id is the single source of truth; the Overview picker renders from it.
    # (updateSelectInput sends a message to the browser, and testServer does not echo that
    # back as input$dataset, so the sync is checked through the rendered picker instead.)
    session$setInputs(overview_dataset = "scenario_one_bad")
    expect_equal(overview_dataset_id(), "scenario_one_bad")
    html <- paste(unlist(output$overview_dataset_picker), collapse = " ")
    expect_match(html, 'value="scenario_one_bad" selected', fixed = TRUE,
                 info = "the picker must show the dataset that is actually loaded")

    # Data page -> Overview: the button path writes the same single source of truth.
    session$setInputs(dataset = "scenario_one_good")
    session$setInputs(load_demo = 1)
    expect_equal(overview_dataset_id(), "scenario_one_good")
    html2 <- paste(unlist(output$overview_dataset_picker), collapse = " ")
    expect_match(html2, 'value="scenario_one_good" selected', fixed = TRUE,
                 info = "the Overview picker must follow the Data page's load")

    # Back to the general demo, and the numbers come back.
    session$setInputs(overview_dataset = "general")
    expect_equal(overview_dataset_id(), "general")
    expect_equal(summary_numbers()$units_at_risk, 283)
  })
})

test_that("every dataset choice is offered with a real label", {
  # A relative-index slip made the "general" choice render with an NA name.
  # names() are the display labels; the values are the internal dataset ids.
  labels <- names(env$DATASET_CHOICES)
  values <- unname(env$DATASET_CHOICES)

  expect_setequal(values, names(env$DATASETS))
  expect_false(any(is.na(labels)), info = "no choice may render with an NA label")
  expect_false(any(is.na(values)))
  expect_true(all(nchar(labels) > 0))
  # And each id carries its own label, not another dataset's.
  expect_equal(values[labels == "General demo (planted failures)"], "general")
  expect_equal(unname(env$DATASET_LABELS[values]), labels)
})

test_that("re-picking the loaded dataset changes nothing", {
  shiny::testServer(env$server, {
    session$setInputs(overview_dataset = "scenario_one_good")
    before <- summary_numbers()$units_at_risk
    session$setInputs(overview_dataset = "scenario_one_good")
    expect_equal(summary_numbers()$units_at_risk, before)
    expect_equal(overview_dataset_id(), "scenario_one_good")
  })
})

test_that("the picker re-renders with every dataset still offered", {
  # The picker renders selected = the loaded dataset, so it re-renders on every switch.
  # A re-render that dropped options, or kept a stale selection, would strand the manager
  # on a dataset they cannot leave.
  shiny::testServer(env$server, {
    session$setInputs(overview_dataset = "scenario_one_bad")
    html <- paste(unlist(output$overview_dataset_picker), collapse = " ")
    for (id in names(env$DATASETS)) {
      expect_match(html, sprintf('value="%s"', id), fixed = TRUE,
                   info = paste("option must survive the re-render:", id))
    }
    expect_match(html, 'value="scenario_one_bad" selected', fixed = TRUE)

    session$setInputs(overview_dataset = "scenario_one_good")
    html2 <- paste(unlist(output$overview_dataset_picker), collapse = " ")
    expect_match(html2, 'value="scenario_one_good" selected', fixed = TRUE)
    expect_false(grepl('value="scenario_one_bad" selected', html2, fixed = TRUE),
                 info = "no stale selection may stick")
  })
})

test_that("an upload makes the picker admit the numbers are not a dataset", {
  # If the manager uploads their own files, the Overview is no longer showing any of the
  # three datasets, so the dropdown must say so instead of naming one of them.
  shiny::testServer(env$server, {
    expect_false(isTRUE(rv$manual_upload))

    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)
    utils::write.csv(data.frame(fridge_id = "F01", blood_type = "O+", blood_units = 5),
                     tmp, row.names = FALSE)
    session$setInputs(up_inventory = list(name = "inv.csv", datapath = tmp))
    expect_true(isTRUE(rv$manual_upload), info = "an upload must raise the flag")

    html <- paste(unlist(output$overview_dataset_picker), collapse = " ")
    expect_match(html, "Uploaded files are in use", fixed = TRUE)

    # Loading a dataset replaces the upload, so the warning must go away again.
    session$setInputs(overview_dataset = "scenario_one_bad")
    expect_false(isTRUE(rv$manual_upload))
    html2 <- paste(unlist(output$overview_dataset_picker), collapse = " ")
    expect_false(grepl("Uploaded files are in use", html2, fixed = TRUE))
  })
})
