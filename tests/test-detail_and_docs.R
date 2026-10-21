# H-43: the generator is a choice on Fridge and Generator Detail, and Docs
# holds the team, the method, and the codebook link. No statistic moves.
library(testthat)

app_dir <- if (file.exists("app/app.R")) "app" else "../app"
data_dir <- if (file.exists("data/readings.csv")) "data" else "../data"

app_exprs <- parse(file.path(app_dir, "app.R"))
is_launch <- function(e) is.call(e) && identical(as.character(e[[1]]), "shinyApp")
env <- new.env(parent = globalenv())
old_wd <- setwd(app_dir)
for (e in app_exprs[!vapply(app_exprs, is_launch, logical(1))]) eval(e, envir = env)
setwd(old_wd)

ui_html <- as.character(env$ui)

test_that("the generator is a choice on the detail page, not its own tab", {
  expect_match(ui_html, "Fridge and Generator Detail", fixed = TRUE)
  expect_false(grepl("data-value=\"Backup generator\"", ui_html, fixed = TRUE),
               info = "there is no Backup generator tab")
  expect_match(ui_html, "not a seventh fridge", fixed = TRUE)
  expect_match(ui_html, "gen_ind_chart", fixed = TRUE)
  expect_match(ui_html, "gen_mr_chart", fixed = TRUE)
  # The fridge charts stay, in the same order, for a fridge choice.
  xbar_at <- regexpr("xbar_chart", ui_html, fixed = TRUE)[1]
  range_at <- regexpr("range_chart", ui_html, fixed = TRUE)[1]
  sd_at <- regexpr("sd_chart", ui_html, fixed = TRUE)[1]
  expect_true(xbar_at < range_at && range_at < sd_at)
})

test_that("choosing the generator renders the transfer charts and a fridge still renders", {
  skip_if_not(file.exists(file.path(data_dir, "generator_log.csv")))
  shiny::testServer(env$server, {
    session$setInputs(fridge = "generator", color_mode = "light")
    note <- paste(unlist(output$generator_note), collapse = " ")
    expect_match(note, "30 transfer tests", fixed = TRUE)
    expect_match(note, "10 s threshold", fixed = TRUE)
    ind <- paste(unlist(output$gen_ind_chart), collapse = " ")
    expect_true(nchar(ind) > 0)
    expect_match(ind, "Individuals", fixed = TRUE)

    session$setInputs(fridge = "F02")
    expect_equal(detail()$fridge_id, "F02")
    expect_true(nchar(paste(unlist(output$xbar_chart), collapse = " ")) > 0)
  })
})

test_that("the Docs page names the team and starts every dropdown closed", {
  expect_match(ui_html, "Hannah Brine", fixed = TRUE)
  expect_match(ui_html, "Sue Cho", fixed = TRUE)
  expect_match(ui_html, "Tanya Schilling", fixed = TRUE)
  expect_match(ui_html, "The Team", fixed = TRUE)
  expect_false(grepl("Meet The Team", ui_html, fixed = TRUE))
  expect_match(ui_html, "Fridge temperature recordings the lab already logs", fixed = TRUE)
  expect_false(grepl("Known answer in workflow.R", ui_html, fixed = TRUE),
               info = "the summary no longer has a tests fact")
  for (title in c("How to use", "Statistical Methods", "Data",
                  "Tests and Verification", "Assumptions and Limitations")) {
    expect_match(ui_html, title, fixed = TRUE, info = title)
  }
  expect_match(ui_html, "bbm-docsec", fixed = TRUE)
  expect_match(ui_html, "Cpk = distance / (3 * sigma short)", fixed = TRUE)
  expect_match(ui_html, "4,032 rows", fixed = TRUE)
  expect_match(ui_html, "RPN = severity * occurrence * urgency", fixed = TRUE)
  expect_match(ui_html, "Expand all", fixed = TRUE)
  expect_match(ui_html, "Keep It Cool", fixed = TRUE)
  expect_false(grepl("<details open", ui_html, fixed = TRUE))
  expect_match(ui_html, "https://github.com/rubberduckysmiles/Rwedoneyet/blob/main/CODEBOOK.md",
               fixed = TRUE)
  expect_false(grepl("lag-1 = cor", ui_html, fixed = TRUE))
  expect_false(grepl("line = lm(hourly mean", ui_html, fixed = TRUE))
  expect_match(ui_html, "1\u20136", fixed = TRUE)
  expect_match(ui_html, "3.2437456007", fixed = TRUE,
               info = "the known-answer Cpk is quoted, not recomputed on the page")
})
