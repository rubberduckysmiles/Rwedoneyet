# The Fridge Detail standard deviation (s) chart: the UI must carry the card and
# the server must fill it. This is the Shiny-layer test; the statistics live in
# test-sd_chart.R. It follows the same shape as test-app_bloodtype_section.R:
# parse app.R, skip the final shinyApp() call, run the real server function.
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

test_that("the Fridge Detail panel carries the s-chart card, after the range chart", {
  ui_html <- as.character(env$ui)
  expect_match(ui_html, "sd_chart", fixed = TRUE)
  # The card order is xbar, range, sd, blood types, violations.
  xbar_at <- regexpr("xbar_chart", ui_html, fixed = TRUE)[1]
  range_at <- regexpr("range_chart", ui_html, fixed = TRUE)[1]
  sd_at <- regexpr("sd_chart", ui_html, fixed = TRUE)[1]
  bt_at <- regexpr("bloodtype_chart", ui_html, fixed = TRUE)[1]
  expect_true(xbar_at < range_at, info = "xbar before range")
  expect_true(range_at < sd_at, info = "range before s-chart")
  expect_true(sd_at < bt_at, info = "s-chart before blood types")
})

test_that("the server renders the s-chart with its own frozen limits", {
  shiny::testServer(env$server, {
    # F02 is the drifting fridge, so its dispersion has something to show.
    session$setInputs(fridge = "F02", color_mode = "light")

    a <- detail()
    lim <- a$baseline$limits$sd
    expect_false(is.null(lim))
    expect_equal(lim$center, lim$c4 * a$baseline$sigma_short, tolerance = 1e-12)

    # The rendered output is plotly JSON, and it names the three limit lines.
    chart_txt <- paste(unlist(output$sd_chart), collapse = " ")
    expect_true(nchar(chart_txt) > 0)
    expect_match(chart_txt, "Center", fixed = TRUE)
    expect_match(chart_txt, "UCL", fixed = TRUE)
    expect_match(chart_txt, "LCL", fixed = TRUE)
    expect_match(chart_txt, "Hourly s", fixed = TRUE)

    # Switching fridges re-renders against that fridge's own baseline.
    session$setInputs(fridge = "F01")
    a01 <- detail()
    expect_false(isTRUE(all.equal(a$baseline$limits$sd$center,
                                  a01$baseline$limits$sd$center)))
    expect_true(nchar(paste(unlist(output$sd_chart), collapse = " ")) > 0)
  })
})

test_that("the s-chart's flags stay off the violations table and the badge", {
  shiny::testServer(env$server, {
    session$setInputs(fridge = "F02", color_mode = "light")
    a <- detail()
    # Whatever the s-chart flags, the violations table names only X-bar and Range.
    expect_true(all(a$violations$chart %in% c("X-bar", "Range")))
  })
})
