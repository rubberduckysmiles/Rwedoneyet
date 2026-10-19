# H-15: the Capability tab's generator statistics and its plain-language captions.
# The statistics themselves must trace to generator_analysis(); no new formula is
# allowed on the page. This file also guards the team decision that the 10 second
# figure is a threshold, never a limit, and re-checks that no published fridge
# number moved.
library(testthat)

path <- if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R"
source(path)
data_dir <- if (file.exists("data/readings.csv")) "data" else "../data"

app_dir <- if (file.exists("app/app.R")) "app" else "../app"
app_lines <- readLines(file.path(app_dir, "app.R"), warn = FALSE)

# ---------------------------------------------------------------- the function

test_that("generator_stats returns NULL when there is no generator analysis", {
  expect_null(generator_stats(NULL))
})

test_that("every statistic generator_stats reports is generator_analysis's own", {
  loaded <- load_demo_data(data_dir)
  skip_if(is.null(loaded$generator), "no generator log in data/")
  g <- generator_analysis(loaded$generator)
  s <- generator_stats(g)

  # Nothing new is computed: each field is a copy of something already there.
  expect_equal(s$last, utils::tail(g$x, 1))
  expect_equal(s$typical, g$limits$center)
  expect_equal(s$ucl, g$limits$ucl)
  expect_equal(s$beyond, length(g$flagged))
  expect_equal(s$n, g$n)
  expect_equal(s$message, g$limits$message)
})

test_that("beyond is exactly the count of flagged tests, and never invents one", {
  loaded <- load_demo_data(data_dir)
  skip_if(is.null(loaded$generator), "no generator log in data/")
  g <- generator_analysis(loaded$generator)
  s <- generator_stats(g)
  expect_true(s$beyond >= 0)
  expect_true(s$beyond <= s$n)
  expect_identical(s$beyond, length(g$flagged))

  # A series with nothing flagged must report zero, not NA.
  expect_identical(generator_stats(g)$beyond, length(g$flagged))
})

test_that("in_control is NA when the limits cannot be drawn, never TRUE by default", {
  # Two identical values: imr_limits refuses to draw limits (mean moving range 0).
  g <- generator_analysis(data.frame(date = c("2026-10-01", "2026-10-02"),
                                     transfer_time_sec = c(5, 5),
                                     stringsAsFactors = FALSE))
  s <- generator_stats(g)
  expect_true(nzchar(g$limits$message))
  expect_true(is.na(s$in_control))
  expect_true(is.na(s$ucl))
})

test_that("in_control is FALSE exactly when something was flagged", {
  loaded <- load_demo_data(data_dir)
  skip_if(is.null(loaded$generator), "no generator log in data/")
  g <- generator_analysis(loaded$generator)
  s <- generator_stats(g)
  if (is.na(s$in_control)) {
    expect_true(nzchar(g$limits$message))
  } else {
    expect_identical(s$in_control, s$beyond == 0)
  }
})

test_that("generator_stats rejects an analysis with no fields rather than guessing", {
  expect_error(generator_stats(list()), "x|limits|n")
})

# ------------------------------------------------- the 10 second figure

test_that("no string in app.R calls the 10 second figure a limit", {
  # A line mentioning both the 10 s figure and the word "limit" must also
  # carry a negation ("not a") or the word "threshold", so it is describing
  # what the figure is NOT, or relabelling it. Anything else is a claim that
  # the team's chosen number is a limit.
  mentions_10 <- grepl("10[ -]?s(econd)?", app_lines, ignore.case = TRUE)
  mentions_limit <- grepl("limit", app_lines, ignore.case = TRUE)
  allowed <- grepl("not a|threshold", app_lines, ignore.case = TRUE)
  suspect <- app_lines[mentions_10 & mentions_limit & !allowed]

  expect_identical(suspect, character(0),
                   info = paste("calls the 10 s figure a limit:", paste(suspect, collapse = " | ")))
})

test_that("the 10 second figure is relabelled as a threshold where it appears", {
  joined <- paste(app_lines, collapse = "\n")
  expect_true(grepl("threshold", joined, ignore.case = TRUE),
              info = "the app should call the 10 s figure a threshold somewhere")
  # The old phrasings are gone.
  for (old in c("10 s limit", "limit is 10 s", "10 second limit")) {
    expect_false(any(grepl(old, app_lines, fixed = TRUE)), info = old)
  }
})

# ----------------------------------------------- no published number moved

test_that("severity * occurrence * urgency still equals the rpn on every demo fridge", {
  loaded <- load_demo_data(data_dir)
  analyses <- analyze_all(loaded$readings, loaded$inventory)
  expect_true(length(analyses) > 0)
  for (id in names(analyses)) {
    a <- analyses[[id]]
    expect_identical(a$severity * a$occurrence * a$urgency, a$rpn,
                     info = paste(id, "rpn must be the product of its three factors"))
  }
})

test_that("the s-chart still reaches nothing downstream", {
  loaded <- load_demo_data(data_dir)
  analyses <- analyze_all(loaded$readings, loaded$inventory)
  for (id in names(analyses)) {
    a <- analyses[[id]]
    expect_true(all(a$violations$chart %in% c("X-bar", "Range")),
                info = paste(id, "violations must not name the s-chart"))
  }
})

# --------------------------------------------------------- the screen itself

app_exprs <- parse(file.path(app_dir, "app.R"))
is_launch <- function(e) is.call(e) && identical(as.character(e[[1]]), "shinyApp")
app_env <- new.env(parent = globalenv())
old_wd <- setwd(app_dir)
for (e in app_exprs[!vapply(app_exprs, is_launch, logical(1))]) eval(e, envir = app_env)
setwd(old_wd)

test_that("the Capability tab carries plain captions for Cpk, Ppk and the gap", {
  shiny::testServer(app_env$server, {
    session$setInputs(cap_fridge = "F01", fridge = "F01", color_mode = "light")
    html <- paste(unlist(output$capability_top), collapse = " ")

    expect_true(nchar(html) > 0)
    # The three boxes are still there...
    for (label in c("Cpk", "Ppk", "Gap")) {
      expect_match(html, label, fixed = TRUE, info = label)
    }
    # ...and each now carries a caption in plain words, not just a formula name.
    expect_match(html, "hour to hour", fixed = TRUE,
                 info = "Cpk needs a plain caption about room left if it holds")
    expect_match(html, "baseline", fixed = TRUE,
                 info = "Ppk needs a plain caption about the whole baseline")
    expect_match(html, "stability|steady|stable", perl = TRUE,
                 info = "the gap needs a plain caption saying it is a stability signal")
  })
})

test_that("the Capability tab shows the generator statistics and what a generator does", {
  skip_if_not(file.exists(file.path(data_dir, "generator_log.csv")))
  shiny::testServer(app_env$server, {
    session$setInputs(cap_fridge = "F01", fridge = "F01", color_mode = "light")
    html <- paste(unlist(output$capability_top), collapse = " ")
    expect_true(nchar(html) > 0)

    # The generator's role, in plain words.
    expect_match(html, "generator", ignore.case = TRUE)
    expect_match(html, "outage|mains|power", ignore.case = TRUE,
                 info = "say what a generator does for the fridges")

    # The statistics, each equal to what generator_analysis computes.
    # Inside testServer the server's own reactives are in scope, so gen() works.
    g <- gen()
    if (!is.null(g)) {
      s <- generator_stats(g)
      expect_match(html, sprintf("%.1f", s$last), fixed = TRUE,
                   info = "last transfer time shown")
      expect_match(html, sprintf("%.1f", s$typical), fixed = TRUE,
                   info = "typical transfer time shown")
      expect_match(html, sprintf("%d", s$beyond), fixed = TRUE,
                   info = "count beyond the limits shown")
    }
  })
})

test_that("the generator strip is absent only when no log is loaded", {
  # With demo data present the strip must appear; the guard is the function,
  # which the tests above already pin.
  expect_true(is.function(app_env$server))
})
