# The Fridge Detail blood-type section: the UI must show it and the server must fill it.
# This is the only test that touches the Shiny layer. It parses app.R, skips the final
# shinyApp() call, and runs the real server function with shiny::testServer.
# The statistics themselves are tested in test-bloodtypes.R; this file only proves the
# screens are wired to them.
library(testthat)
skip_if_not_installed("shiny")

app_dir <- if (file.exists("app/app.R")) "app" else "../app"

exprs <- parse(file.path(app_dir, "app.R"))
is_launch_call <- function(e) is.call(e) && identical(as.character(e[[1]]), "shinyApp")
env <- new.env(parent = globalenv())
# app.R finds qc.R and the CSVs from the working directory, so evaluate it while
# sitting in app/, the same way runApp("app") would, then come straight back.
old_wd <- setwd(app_dir)
for (e in exprs[!vapply(exprs, is_launch_call, logical(1))]) eval(e, envir = env)
setwd(old_wd)

test_that("the Fridge Detail panel carries the blood-type card", {
  ui_html <- as.character(env$ui)
  expect_match(ui_html, "Blood types in this fridge", fixed = TRUE)
  expect_match(ui_html, "bloodtype_chart", fixed = TRUE)
})

test_that("the server fills the blood-type chart and note from the inventory", {
  shiny::testServer(env$server, {
    # F02 is the drifting fridge: red badge, so all 180 bags are at risk.
    session$setInputs(fridge = "F02", color_mode = "light")
    bt <- bloodtype_data()
    expect_gt(nrow(bt), 1)
    expect_equal(sum(bt$blood_units), 180)
    expect_equal(sum(bt$units_at_risk), 180)

    chart_txt <- paste(unlist(output$bloodtype_chart), collapse = " ")
    expect_true(grepl("O+", chart_txt, fixed = TRUE))
    expect_true(grepl("AB-", chart_txt, fixed = TRUE))

    note <- paste(as.character(output$bloodtype_note), collapse = " ")
    expect_match(note, "at risk", fixed = TRUE)

    # F01 is healthy: nothing at risk, and the note says so.
    session$setInputs(fridge = "F01")
    expect_equal(sum(bloodtype_data()$units_at_risk), 0)
    note_f01 <- paste(as.character(output$bloodtype_note), collapse = " ")
    expect_match(note_f01, "inside the spec", fixed = TRUE)
  })
})
