# H-12: every number on screen explained where the user meets it.
#
# A caption sits next to the number it explains - in app.R - and must be
# checkable against the code. Nothing here may invent a formula. Two rules are
# pinned hard: the three risk factors MULTIPLY to the rpn shown on the card
# (the app calls rpn(severity, occurrence, urgency)), and the 10 second figure
# is a threshold the team chose and the manager sets for their own site.
library(testthat)

path <- if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R"
source(path)

data_dir <- if (file.exists("data/readings.csv")) "data" else "../data"
app_dir <- if (file.exists("app/app.R")) "app" else "../app"

# Build the app's ui and server, the same recipe as test-capability_generator.R.
app_exprs <- parse(file.path(app_dir, "app.R"))
is_launch <- function(e) is.call(e) && identical(as.character(e[[1]]), "shinyApp")
env <- new.env(parent = globalenv())
old_wd <- setwd(app_dir)
for (e in app_exprs[!vapply(app_exprs, is_launch, logical(1))]) eval(e, envir = env)
setwd(old_wd)

ui_html <- as.character(env$ui)

# The expected breakdowns, computed OUTSIDE testServer on purpose: inside the
# server the name `analyses` is the server's own reactive, so a global of that
# name would be shadowed. This name is unique to this file.
demo <- load_demo_data(data_dir)
all_analyses <- analyze_all(demo$readings, demo$inventory)
fridge_expectations <- vapply(all_analyses, function(a) {
  sprintf("severity %d \u00D7 occurrence %d \u00D7 urgency %d = %d",
          a$severity, a$occurrence, a$urgency, a$rpn)
}, character(1))

# ------------------------------------------------------ the fridge card

test_that("every demo fridge shows its RPN as the product of its three factors", {
  skip_if(length(fridge_expectations) == 0, "no demo readings")

  shiny::testServer(env$server, {
    session$setInputs(fridge = "F01", color_mode = "light")
    html <- paste(unlist(output$fridge_cards), collapse = " ")
    expect_true(nchar(html) > 0)
    expect_match(html, "RPN", fixed = TRUE)

    for (id in names(fridge_expectations)) {
      # Multiplied, never added: severity * occurrence * urgency == rpn.
      expect_match(html, fridge_expectations[[id]], fixed = TRUE,
                   info = paste(id, "card must show", fridge_expectations[[id]]))
    }
  })

  # The identity itself, against the numbers the card prints.
  for (a in all_analyses) {
    expect_identical(a$severity * a$occurrence * a$urgency, a$rpn,
                     info = a$fridge_id)
  }
})

test_that("the fridge card says what each of its four fields means", {
  skip_if(length(fridge_expectations) == 0, "no demo readings")

  shiny::testServer(env$server, {
    session$setInputs(fridge = "F01", color_mode = "light")
    cards <- paste(unlist(output$fridge_cards), collapse = " ")
    notes <- paste(unlist(output$overview_notes), collapse = " ")

    # The column meanings were moved out of the six cards and into the single
    # description card above them, so they are stated once instead of six times.
    # They must still exist on the Overview - check the new home, not the old one.
    expect_match(notes, "bags stored", fixed = TRUE,
                 info = "Blood units must say they are the bags stored")
    expect_match(notes, "nearer of 1", fixed = TRUE,
                 info = "Ppk must say it is measured to the nearer spec limit")
    expect_match(notes, "fitted line", fixed = TRUE,
                 info = "'Out of spec in' must say it is the forecast time")
    expect_match(notes, "first 48 hours", fixed = TRUE,
                 info = "Mean and Std dev must say they come from the baseline")

    # The three factors are named, not just printed, and the per-card arithmetic
    # line stays on each card with that card's own numbers.
    for (word in c("severity", "occurrence", "urgency")) {
      expect_match(notes, word, fixed = TRUE, info = paste("notes:", word))
      expect_match(cards, word, fixed = TRUE, info = paste("cards:", word))
    }

    # And the shared prose must NOT be repeated under every card any more.
    expect_false(grepl("bags stored", cards, fixed = TRUE),
                 info = "the shared column meanings belong in the notes card, not on each card")
  })
})

# ------------------------------------------------------------ the Overview

test_that("Average Ppk explains what Ppk is, not just that it is averaged", {
  skip_if(length(all_analyses) == 0, "no demo readings")

  shiny::testServer(env$server, {
    session$setInputs(fridge = "F01", color_mode = "light")
    html <- paste(unlist(output$overview_boxes), collapse = " ")
    expect_true(nchar(html) > 0)
    expect_match(html, "Average Ppk", fixed = TRUE)
    expect_match(html, "sigmas", fixed = TRUE,
                 info = "say that Ppk is counted in sigmas")
    expect_match(html, "1.0", fixed = TRUE,
                 info = "say what the cutoff for capable is")
  })
})

test_that("the transfer box calls the 10 second figure the team's own threshold", {
  skip_if_not(file.exists(file.path(data_dir, "generator_log.csv")))

  shiny::testServer(env$server, {
    session$setInputs(fridge = "F01", color_mode = "light")
    html <- paste(unlist(output$overview_boxes), collapse = " ")

    expect_match(html, "threshold", fixed = TRUE)
    expect_match(html, "own site", fixed = TRUE,
                 info = "the manager sets it for their own setup")
    expect_match(html, "power", ignore.case = TRUE,
                 info = "say what transfer time measures")
  })
})

# ------------------------------------------- the static cards and the sidebar

test_that("the sidebar says what a zone line is and what it is not", {
  expect_match(ui_html, "standard errors", fixed = TRUE,
               info = "the zone checkbox must name the unit it draws")
  expect_match(ui_html, "not control limits", fixed = TRUE,
               info = "zones must not be readable as limits")
})

test_that("the histogram caption separates the spec lines from the control limits", {
  expect_match(ui_html, "spec limits for stored red cells", fixed = TRUE,
               info = "name what 1 and 6 degrees are for")
  expect_match(ui_html, "control limits come from the process", ignore.case = TRUE,
               info = "and say where the control limits actually live")
})

test_that("the rolling Ppk caption states its window and how to read a fall", {
  expect_match(ui_html, "96 readings", fixed = TRUE,
               info = "the window is 96 readings")
  expect_match(ui_html, "24 hours", fixed = TRUE,
               info = "which is 24 hours at 15-minute readings")
  expect_match(ui_html, "falling line", fixed = TRUE,
               info = "say what a falling line means")
})
