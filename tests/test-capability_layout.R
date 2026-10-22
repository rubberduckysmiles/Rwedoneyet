# H-42: the Capability page leads with the sentence, keeps the card border, and
# marks the two charts. The numbers and the color rules are unchanged.
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
ui_html <- as.character(env$ui)

test_that("the sentence sits on a card whose left edge is the sentence color", {
  skip_if(length(all_analyses) == 0, "no demo readings")

  shiny::testServer(env$server, {
    session$setInputs(fridge = "F02", cap_fridge = "F02", color_mode = "light")
    html <- paste(unlist(output$capability_top), collapse = " ")
    expect_match(html, "Fridge 02 is inside the spec width, but not stable.", fixed = TRUE)
    expect_match(html, "bbm-cap", fixed = TRUE)
    expect_match(html, "card", fixed = TRUE, info = "the card class, and its border, stay")
    expect_match(html, "--bbm-edge:#E8A33D;", fixed = TRUE,
                 info = "inside the spec width but not stable is amber")
    expect_match(html, "<details", fixed = TRUE)
    expect_match(html, "How to read these numbers", fixed = TRUE)
    expect_false(grepl("<details open", html, fixed = TRUE),
                 info = "the how-to-read dropdown starts closed")
    expect_match(html, "last day", fixed = TRUE,
                 info = "say that this color and the Overview badge can disagree")
    expect_false(grepl("Lag-1 autocorrelation", html, fixed = TRUE),
                 info = "the capability notes do not print the lag-1 sentence")
    expect_false(grepl("carries the fridges", html, fixed = TRUE),
                 info = "the generator essay is one line, not the old paragraph")
  })
})

test_that("the other two sentences and a missing baseline take their own edge colors", {
  skip_if(length(all_analyses) == 0, "no demo readings")

  real <- get("analyze_all", envir = env)
  on.exit(assign("analyze_all", real, envir = env), add = TRUE)

  edge_for <- function(sentence) {
    assign("analyze_all", function(readings, inventory) {
      base <- real(readings, inventory)
      a <- base[["F02"]]
      a$capable_sentence <- sentence
      base[["F02"]] <- a
      base
    }, envir = env)
    html <- NULL
    shiny::testServer(env$server, {
      session$setInputs(fridge = "F02", cap_fridge = "F02", color_mode = "light")
      html <<- paste(unlist(output$capability_top), collapse = " ")
    })
    assign("analyze_all", real, envir = env)
    html
  }

  expect_match(edge_for("capable and stable"), "--bbm-edge:#2E9E6B;", fixed = TRUE)
  expect_match(edge_for("not capable"), "--bbm-edge:#D64045;", fixed = TRUE)
  expect_match(edge_for("sigma is 0; Cpk and Ppk are undefined"), "--bbm-edge:#8A8F98;", fixed = TRUE)
})

test_that("the page style paints the edge and does not replace the card shadow", {
  expect_match(ui_html, ".bbm-cap.card { border-left: 7px solid var(--bbm-edge); }", fixed = TRUE)
  expect_false(grepl("bbm-cap.card { box-shadow", ui_html, fixed = TRUE))
  expect_match(ui_html, "cap_fridge", fixed = TRUE, info = "the fridge picker stays on the page")
  expect_match(ui_html, "The band between the lines is 1", fixed = TRUE)
  expect_match(ui_html, "The dashed line is 1.0.", fixed = TRUE)
  expect_match(ui_html, "spec limits for stored red cells", fixed = TRUE)
  expect_match(ui_html, "96 readings", fixed = TRUE)
  expect_match(ui_html, "falling line", fixed = TRUE)
})

test_that("the histogram shades 1 to 6 and the rolling chart marks 1.0", {
  skip_if(length(all_analyses) == 0, "no demo readings")
  a <- all_analyses[["F01"]]

  h <- plotly::plotly_build(env$histogram_plot(a, FALSE))
  rects <- Filter(function(s) identical(s$type, "rect"), h$x$layout$shapes)
  expect_true(length(rects) >= 1, info = "the spec window is a band")
  expect_equal(as.numeric(rects[[1]]$x0), 1)
  expect_equal(as.numeric(rects[[1]]$x1), 6)

  r <- plotly::plotly_build(env$rolling_plot(a, FALSE))
  lines <- Filter(function(s) identical(s$type, "line"), r$x$layout$shapes)
  ys <- vapply(lines, function(s) as.numeric(s$y0), numeric(1))
  expect_true(any(abs(ys - 1) < 1e-8), info = "a line sits at the 1.0 cutoff")
  texts <- vapply(r$x$layout$annotations, function(n) as.character(n$text), character(1))
  expect_true("1.0" %in% texts)
  yr <- r$x$layout$yaxis$range
  expect_true(as.numeric(yr[[1]]) <= 1 && as.numeric(yr[[2]]) >= 1,
              info = "the 1.0 line is inside the axis")
})
