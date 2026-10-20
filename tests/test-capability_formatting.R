# H-37: colour the Capability page's value boxes by their value.
#
# The Overview page colours its three counts by value (H-36). The Capability page has
# SIX value boxes in two cards and printed every one in the same neutral colour, so a
# fridge with Cpk 5.8 looked exactly like a fridge with Cpk 0.4. These tests pin the
# colours and, more importantly, pin that the colour can actually CHANGE.
#
# The demo only ever shows the green half for Cpk and Ppk: all six fridges sit at
# Cpk 4.95-6.28 and Ppk 5.12-6.13, far above the line at 1. A test that read only the
# demo would pass on a box wired permanently to green, so the red branches are driven
# with a controlled analysis result rather than read.
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

# The class on the value span for one box, read out of the rendered HTML.
#
# bslib::value_box() renders the value as <p class="value-box-value">...</p>. We wrap
# that value in a span carrying the colour class, and bslib keeps its own class too, so
# the span reads class="bbm-over value-box-value" (bslib puts its class first). The
# match below therefore looks for the label, then the first class attribute after it,
# and does not assume the colour class comes first.
value_class <- function(html, label) {
  h <- paste(unlist(html), collapse = " ")
  # The label sits in <p class="value-box-title">LABEL</p>; the value follows it.
  pat <- sprintf('<p class="value-box-title">%s</p>\\s*<(?:p|span) class="([^"]*)"', label)
  m <- regmatches(h, gregexpr(pat, h))[[1]]
  if (length(m) == 0) return(NA_character_)
  sub('^.*class="([^"]*)"$', '\\1', m[1])
}

# TRUE when the class string carries the named colour class.
has_class <- function(cls, want) {
  if (length(cls) != 1 || is.na(cls)) return(FALSE)
  grepl(sprintf("(^| )%s( |$)", want), cls)
}

# The six rules, as the app computes them. These are asserted through the RENDERED
# boxes below, so re-stating them here only documents intent; the real check is that
# the box follows them.
#   Cpk, Ppk            >= 1 green, < 1 red, NA uncoloured
#   Gap                 |Gap| < 0.10 green, else red, NA uncoloured
#   Last/Typical transfer   <= 10 green, > 10 red
#   Tests beyond        0 green, >= 1 red

test_that("the capability boxes are green on the demo and carry no colour when NA", {
  skip_if(length(all_analyses) == 0, "no demo readings")

  shiny::testServer(env$server, {
    session$setInputs(fridge = "F02", cap_fridge = "F02", color_mode = "light")
    html <- output$capability_top

    # The demo's Cpk and Ppk are far above 1, so both must read green.
    expect_true(all_analyses[["F02"]]$cpk >= 1, info = "F02 must be on the green side")
    expect_true(all_analyses[["F02"]]$ppk >= 1, info = "F02 must be on the green side")
    expect_true(has_class(value_class(html, "Cpk \\(short-term sigma\\)"), "bbm-ok"),
                info = "Cpk above 1 must be green")
    expect_true(has_class(value_class(html, "Ppk \\(overall sigma\\)"), "bbm-ok"),
                info = "Ppk above 1 must be green")
  })
})

test_that("a Cpk or Ppk below 1 turns the box red, driven through the real server", {
  # The demo never goes below 1, so the red branch is constructed. analyses() is the
  # reactive the Capability page reads, so feeding it a controlled result exercises the
  # app's OWN boundary expression - not a copy of it. A copy would still pass if the app
  # flipped >= to >.
  skip_if(length(all_analyses) == 0, "no demo readings")

  real <- get("analyze_all", envir = env)
  on.exit(assign("analyze_all", real, envir = env), add = TRUE)

  render_with <- function(cpk, ppk, gap) {
    assign("analyze_all", function(readings, inventory) {
      base <- real(readings, inventory)
      a <- base[["F02"]]
      a$cpk <- cpk; a$ppk <- ppk; a$gap <- gap
      base[["F02"]] <- a
      base
    }, envir = env)

    html <- NULL
    shiny::testServer(env$server, {
      session$setInputs(fridge = "F02", cap_fridge = "F02", color_mode = "light")
      html <<- output$capability_top
    })
    assign("analyze_all", real, envir = env)
    html
  }

  # Just below the line is red; exactly 1 is green (>= 1); above is green.
  below <- render_with(cpk = 0.99, ppk = 5, gap = 0)
  expect_true(has_class(value_class(below, "Cpk \\(short-term sigma\\)"), "bbm-over"),
              info = "Cpk just below 1 must be red")
  expect_false(has_class(value_class(below, "Cpk \\(short-term sigma\\)"), "bbm-ok"))

  at_one <- render_with(cpk = 1, ppk = 1, gap = 0.5)
  expect_true(has_class(value_class(at_one, "Cpk \\(short-term sigma\\)"), "bbm-ok"),
              info = "Cpk exactly 1 must be green (>= 1)")
  expect_true(has_class(value_class(at_one, "Ppk \\(overall sigma\\)"), "bbm-ok"),
              info = "Ppk exactly 1 must be green (>= 1)")

  pbelow <- render_with(cpk = 5, ppk = 0.42, gap = 0.5)
  expect_true(has_class(value_class(pbelow, "Ppk \\(overall sigma\\)"), "bbm-over"),
              info = "Ppk below 1 must be red")
})

test_that("NA keeps the default colour, the way the Overview's Average Ppk does", {
  # A fridge with no usable baseline limits yet is neither good nor bad news. Reported
  # as NA, it must carry NO colour class at all - not green, not red.
  skip_if(length(all_analyses) == 0, "no demo readings")

  real <- get("analyze_all", envir = env)
  on.exit(assign("analyze_all", real, envir = env), add = TRUE)

  assign("analyze_all", function(readings, inventory) {
    base <- real(readings, inventory)
    a <- base[["F02"]]
    a$cpk <- NA_real_; a$ppk <- NA_real_; a$gap <- NA_real_
    base[["F02"]] <- a
    base
  }, envir = env)

  html <- NULL
  shiny::testServer(env$server, {
    session$setInputs(fridge = "F02", cap_fridge = "F02", color_mode = "light")
    html <<- output$capability_top
  })
  assign("analyze_all", real, envir = env)

  for (lbl in c("Cpk \\(short-term sigma\\)", "Ppk \\(overall sigma\\)", "Gap \\(Cpk minus Ppk\\)")) {
    cls <- value_class(html, lbl)
    expect_false(has_class(cls, "bbm-ok"), info = paste(lbl, "NA must not be green"))
    expect_false(has_class(cls, "bbm-over"), info = paste(lbl, "NA must not be red"))
    # It still has the value-box class bslib always adds, so it is a real value.
    expect_true(grepl("value-box-value", cls, fixed = TRUE),
                info = paste(lbl, "must still render as a value"))
  }
})

test_that("Gap is judged by magnitude, so an equal negative and positive Gap agree", {
  # Gap is signed and negative on the demo (F01 -0.06, F05 -0.17, F06 -0.17, meaning
  # Ppk > Cpk). The caption calls a near-zero Gap steady without saying which sign is
  # bad, so the team's rule is |Gap| < 0.10 green. This pins that symmetry: -0.29 and
  # +0.29 must get the SAME colour, and neither may be green.
  skip_if(length(all_analyses) == 0, "no demo readings")

  real <- get("analyze_all", envir = env)
  on.exit(assign("analyze_all", real, envir = env), add = TRUE)

  render_gap <- function(gap) {
    assign("analyze_all", function(readings, inventory) {
      base <- real(readings, inventory)
      a <- base[["F02"]]
      a$cpk <- 5; a$ppk <- 5; a$gap <- gap
      base[["F02"]] <- a
      base
    }, envir = env)
    html <- NULL
    shiny::testServer(env$server, {
      session$setInputs(fridge = "F02", cap_fridge = "F02", color_mode = "light")
      html <<- output$capability_top
    })
    assign("analyze_all", real, envir = env)
    value_class(html, "Gap \\(Cpk minus Ppk\\)")
  }

  near_pos <- render_gap(0.05)
  near_neg <- render_gap(-0.05)
  far_pos <- render_gap(0.29)
  far_neg <- render_gap(-0.29)

  # Near zero is steady, either sign.
  expect_true(has_class(near_pos, "bbm-ok"), info = "Gap +0.05 is steady, so green")
  expect_true(has_class(near_neg, "bbm-ok"), info = "Gap -0.05 is steady, so green")

  # Clearly off zero is a stability signal, either sign.
  expect_true(has_class(far_pos, "bbm-over"), info = "Gap +0.29 must be red")
  expect_true(has_class(far_neg, "bbm-over"),
              info = "Gap -0.29 must be red: magnitude, not sign")
})

test_that("the generator boxes use the team-chosen 10 s line, not the control limit", {
  # The team chose the 10 s threshold so the Capability card and the Overview box always
  # agree. The generator chart's own upper control limit is 13.83 s on the demo, so a
  # last transfer of 12 s sits BETWEEN the two numbers: it must read RED under the 10 s
  # rule, which is what distinguishes the two choices.
  skip_if(length(all_analyses) == 0, "no demo readings")
  skip_if(is.null(demo$generator) || nrow(demo$generator) == 0, "no demo generator log")

  g <- get("generator_analysis", envir = env)(demo$generator)
  s <- generator_stats(g)
  expect_equal(round(s$ucl, 2), 13.83,
               info = "the demo's control limit must really be 13.83 for this test to bite")
  expect_true(s$last > 10, info = "the demo's last transfer is 48 s, above the 10 s line")

  shiny::testServer(env$server, {
    session$setInputs(fridge = "F02", cap_fridge = "F02", color_mode = "light")
    html <- output$capability_top

    # 48 s is above 10, so red. It is well above both lines, so this alone does not
    # separate them - the constructed case in the next test does.
    expect_true(has_class(value_class(html, "Last transfer"), "bbm-over"),
                info = "48 s must be red against the 10 s line")

    # Typical transfer is 7.55 s, at or below 10, so green.
    expect_true(has_class(value_class(html, "Typical transfer"), "bbm-ok"),
                info = "7.55 s is at or below the 10 s line, so green")

    # 1 test beyond the limits is not zero, so red.
    expect_true(has_class(value_class(html, "Tests beyond the limits"), "bbm-over"),
                info = "1 test beyond must be red: zero is the good case")
  })
})

test_that("a transfer between the 10 s line and the control limit reads red", {
  # This is the case that tells the two possible rules apart. 12 s is above the
  # team-chosen 10 s but below the chart's own 13.83 s control limit, so it must be RED.
  # If someone later switched the rule to the control limit, this test fails.
  skip_if(length(all_analyses) == 0, "no demo readings")
  skip_if(is.null(demo$generator) || nrow(demo$generator) == 0, "no demo generator log")

  real_gs <- get("generator_stats", envir = env)
  on.exit(assign("generator_stats", real_gs, envir = env), add = TRUE)

  render_transfer <- function(last, typical, beyond) {
    assign("generator_stats", function(g) {
      s <- real_gs(g)
      s$last <- last; s$typical <- typical; s$beyond <- beyond
      s
    }, envir = env)
    html <- NULL
    shiny::testServer(env$server, {
      session$setInputs(fridge = "F02", cap_fridge = "F02", color_mode = "light")
      html <<- output$capability_top
    })
    assign("generator_stats", real_gs, envir = env)
    html
  }

  between <- render_transfer(last = 12, typical = 12, beyond = 0)
  expect_true(has_class(value_class(between, "Last transfer"), "bbm-over"),
              info = "12 s is above the 10 s team line, so red even though < 13.83")
  expect_true(has_class(value_class(between, "Typical transfer"), "bbm-over"),
              info = "typical 12 s is above the 10 s line, so red")

  at_line <- render_transfer(last = 10, typical = 10, beyond = 0)
  expect_true(has_class(value_class(at_line, "Last transfer"), "bbm-ok"),
              info = "exactly 10 s is at the line, so green")
  expect_true(has_class(value_class(at_line, "Typical transfer"), "bbm-ok"),
              info = "exactly 10 s is at the line, so green")
  expect_true(has_class(value_class(at_line, "Tests beyond the limits"), "bbm-ok"),
              info = "zero tests beyond is the good case, so green")

  over <- render_transfer(last = 20, typical = 3, beyond = 2)
  expect_true(has_class(value_class(over, "Last transfer"), "bbm-over"))
  expect_true(has_class(value_class(over, "Typical transfer"), "bbm-ok"))
  expect_true(has_class(value_class(over, "Tests beyond the limits"), "bbm-over"))
})

test_that("the colours are classes, not styles: no number is changed by them", {
  # Colour only. The figures themselves must be identical whether the class is present
  # or not, so this pins that the boxes still print the demo's real numbers.
  skip_if(length(all_analyses) == 0, "no demo readings")

  shiny::testServer(env$server, {
    session$setInputs(fridge = "F02", cap_fridge = "F02", color_mode = "light")
    html <- paste(unlist(output$capability_top), collapse = " ")

    a <- all_analyses[["F02"]]
    # The visible text of each value is the formatted statistic, unchanged.
    expect_match(html, env$fmt_num(a$cpk, 2), fixed = TRUE)
    expect_match(html, env$fmt_num(a$ppk, 2), fixed = TRUE)
    expect_match(html, env$fmt_num(a$gap, 2), fixed = TRUE)
    # And the captions are still there, so nothing was replaced by a bare number.
    expect_match(html, "Above 1.0 is room to spare", fixed = TRUE)
    expect_match(html, "stability signal, not a score", fixed = TRUE)
  })
})

test_that("the Capability page colours nothing green when no generator log is loaded", {
  # The generator card shows a message instead of boxes when there is no log, so there
  # must be no half-coloured card left behind, and the capability boxes still work.
  skip_if(length(all_analyses) == 0, "no demo readings")

  real_load <- get("load_demo_data", envir = env)
  real_an <- get("analyze_all", envir = env)
  on.exit({
    assign("load_demo_data", real_load, envir = env)
    assign("analyze_all", real_an, envir = env)
  }, add = TRUE)

  # Drive the server with no generator by clearing the reactive's source.
  assign("load_demo_data", function(dir) {
    d <- real_load(dir)
    d$generator <- NULL
    d
  }, envir = env)

  html <- NULL
  shiny::testServer(env$server, {
    session$setInputs(fridge = "F02", cap_fridge = "F02", color_mode = "light")
    html <<- output$capability_top
  })
  assign("load_demo_data", real_load, envir = env)

  h <- paste(unlist(html), collapse = " ")
  expect_match(h, "No backup generator log loaded", fixed = TRUE)
  # The capability boxes are still present and still green.
  expect_true(has_class(value_class(html, "Cpk \\(short-term sigma\\)"), "bbm-ok"))
})
