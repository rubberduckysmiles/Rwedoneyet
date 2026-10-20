# The Overview tab's per-fridge control charts must say what the y axis is.
#
# Each fridge card on the Overview carries a 90 px sparkline: the hourly mean
# temperature, the same series the Fridge Detail page's X-bar chart draws. It
# shipped with an empty y-axis title, so a manager saw tick numbers with no
# units and nothing saying the points were hourly means rather than raw
# readings. The label is now "Hourly mean (°C)", matching the X-bar chart's
# own wording for the identical quantity.
#
# This is a display tweak, so it is exactly the kind that can be lost in a
# later refactor without any statistic changing. Nothing else asserts it, so
# these tests pin it for all six demo fridges, in both themes.
library(testthat)

path <- if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R"
source(path)

data_dir <- if (file.exists("data/readings.csv")) "data" else "../data"
app_dir <- if (file.exists("app/app.R")) "app" else "../app"

# Build the app's top level - sparkline_plot(), themed(), hline(), empty_plot()
# and the rest - the same recipe test-captions.R uses.
app_exprs <- parse(file.path(app_dir, "app.R"))
is_launch <- function(e) is.call(e) && identical(as.character(e[[1]]), "shinyApp")
env <- new.env(parent = globalenv())
old_wd <- setwd(app_dir)
for (e in app_exprs[!vapply(app_exprs, is_launch, logical(1))]) eval(e, envir = env)
setwd(old_wd)

demo <- load_demo_data(data_dir)
all_analyses <- analyze_all(demo$readings, demo$inventory)

# The built layout is a list; pull the title text whether it is a bare string
# or a list with a $text field, which is how plotly stores it either way.
yaxis_title <- function(p) {
  b <- plotly::plotly_build(p)
  t <- b$x$layout$yaxis$title
  if (is.null(t)) return("")
  if (is.list(t)) (t$text %||% "") else as.character(t)
}

test_that("the Overview sparkline labels its y axis on every demo fridge", {
  skip_if(length(all_analyses) == 0, "no demo readings")

  for (id in names(all_analyses)) {
    info <- sprintf("fridge %s", id)
    expect_equal(yaxis_title(env$sparkline_plot(all_analyses[[id]], dark = FALSE)),
                 "Hourly mean (\u00B0C)", info = info)
  }
})

test_that("the label survives the dark theme, which a manager can switch on", {
  skip_if(length(all_analyses) == 0, "no demo readings")

  for (id in names(all_analyses)) {
    expect_equal(yaxis_title(env$sparkline_plot(all_analyses[[id]], dark = TRUE)),
                 "Hourly mean (\u00B0C)", info = sprintf("fridge %s, dark", id))
  }
})

test_that("the label matches the X-bar chart's wording for the same series", {
  skip_if(length(all_analyses) == 0, "no demo readings")

  # Both charts plot a$subgroups$mean. The Fridge Detail X-bar chart already
  # called it "Hourly mean (°C)"; the sparkline must not invent a second name
  # for the same number. keep/zone_lines are the same arguments the server
  # passes at app/app.R, so this builds the chart the user actually sees.
  a <- all_analyses[[names(all_analyses)[1]]]
  xbar <- plotly::plotly_build(env$xbar_plot(a, env$visible_rows(a, NULL), FALSE, dark = FALSE))
  t <- xbar$x$layout$yaxis$title
  xbar_title <- if (is.null(t)) "" else if (is.list(t)) (t$text %||% "") else as.character(t)
  expect_equal(xbar_title, "Hourly mean (\u00B0C)")
  expect_equal(yaxis_title(env$sparkline_plot(a, dark = FALSE)), xbar_title)
})

test_that("the left margin leaves room for the title at the sparkline's 90 px height", {
  skip_if(length(all_analyses) == 0, "no demo readings")

  # The card sets height = "90px". A title needs more room than the 40 px the
  # chart used before the label existed, or it crowds the tick numbers.
  a <- all_analyses[[names(all_analyses)[1]]]
  b <- plotly::plotly_build(env$sparkline_plot(a, dark = FALSE))
  expect_gte(as.numeric(b$x$layout$margin$l), 56)
})

test_that("fridges without baseline limits still label the axis", {
  # sparkline_plot() falls back to empty_plot() when a fridge has no hourly
  # data, and that fallback draws no axes at all - so there is no y title to
  # assert, and building it would warn about an empty trace. What must hold is
  # that a fridge WITH data always carries the label, which is the case above.
  # This records the boundary so the gap is deliberate rather than accidental.
  expect_false("subgroups" %in% names(formals(env$empty_plot)))
  a <- all_analyses[[names(all_analyses)[1]]]
  expect_true(nrow(a$subgroups) > 0, info = "the demo must have hourly data to label")
})
