# Bank of Bloody Mary: a Shiny dashboard for the blood-bank lab manager.
# This file only draws screens. Every number comes from a function in app/R/ (see monitor.R).
# Start it from the repo root with:  Rscript app/testme.R

library(shiny)
library(bslib)
library(plotly)
library(DT)

# runApp() sets the working directory to this folder, so qc.R is next to us. The fallback lets
# the file also be sourced from the repo root.
app_dir <- if (file.exists("qc.R")) normalizePath(".") else normalizePath("app")
source(file.path(app_dir, "qc.R"))
# Locally the CSVs live in the repo's data/ folder, one level above app/.
# On Posit Connect the bundle is only this folder, so the same CSVs are also in app/data.
outside_data <- file.path(dirname(app_dir), "data")
inside_data <- file.path(app_dir, "data")
data_dir <- if (dir.exists(outside_data)) outside_data else inside_data

# Dataset picker on the Data page: internal id -> folder under data_dir.
DATASETS <- c(general = "", scenario_one_good = "scenario_one_good",
              scenario_one_bad = "scenario_one_bad")
DATASET_LABELS <- c(general = "General demo (planted failures)",
                    scenario_one_good = "Dataset 1",
                    scenario_one_bad = "Dataset 2")
# One source of truth for the picker's choices and its help text, so the Data page and the
# Overview cannot offer different lists or describe the same dataset in two ways.
# Indexed by dataset id: DATASET_LABELS[DATASETS] would look up the empty folder name, so
# the names are taken from the labels' own names instead.
DATASET_CHOICES <- stats::setNames(names(DATASETS), unname(DATASET_LABELS[names(DATASETS)]))
# "Dataset 1" and "Dataset 2" name the sets but do not say what is in them, so the help
# text carries that: it names the labels and says which is which. The old wording said
# "Good" and "Bad", which were the old labels, and it would now describe names that no
# longer appear anywhere the manager can see.
DATASET_HELP <- paste("General: six fridges with planted failures.",
                      "Dataset 1: six fridges that each behave differently.",
                      "Dataset 2: all six are ordinary noise, nothing fails.")
# The Overview card has room for one line, so this line says what the two names actually
# are. The Data page keeps the longer DATASET_HELP.
DATASET_HELP_SHORT <- "Dataset 2 is ordinary noise. Dataset 1 is the mixed set."

theme <- bslib::bs_theme(preset = "shiny", primary = "#B3202A", font = bslib::font_google("Inter"))

# One color per test number for flagged points. Red, amber and green are kept for status only.
TEST_COLORS <- c("#7B2D8E", "#0072B2", "#56B4E9", "#CC79A7", "#8C564B", "#17BECF", "#555555", "#B8860B")
CAPABLE_SENTENCES <- c("capable and stable", "inside the spec width, but not stable", "not capable")

# The left edge of the Capability card. This is the baseline sentence, which can
# disagree with the Overview badge: the badge looks at the last day only.
capable_edge <- function(sentence) {
  colors <- c(
    "capable and stable" = "#2E9E6B",
    "inside the spec width, but not stable" = "#E8A33D",
    "not capable" = "#D64045"
  )
  if (!is.null(sentence) && sentence %in% names(colors)) unname(colors[[sentence]]) else "#8A8F98"
}

# ---- Small display helpers -----------------------------------------------------------------------

fmt_num <- function(x, digits = 2) {
  if (length(x) != 1 || is.na(x)) "\u2014" else formatC(x, format = "f", digits = digits)
}

time_text <- function(t) format(t, "%Y-%m-%d %H:%M:%S")

`%||%` <- function(a, b) if (is.null(a)) b else a

safe_id <- function(id) gsub("[^A-Za-z0-9_]", "_", id)

# Screen name only. The files and the statistics keep the id, such as F02.
fridge_label <- function(id) {
  ifelse(grepl("^F[0-9]+$", id), paste0("Fridge ", sub("^F", "", id)), as.character(id))
}

status_badge <- function(a) {
  text_color <- if (a$status == "amber") "#212529" else "#FFFFFF"
  tags$span(
    class = "badge rounded-pill",
    style = sprintf("background-color:%s;color:%s;", a$status_color, text_color),
    a$status_label
  )
}

# Theme the plot for light or dark mode and hide the toolbar.
#
# font below sets the plot's default text color, but plotly does NOT let an axis inherit it:
# a chart that passes its own xaxis/yaxis list REPLACES the axis settings rather than merging
# them, so tick numbers fell back to plotly's dark default and were unreadable on the dark page.
# A later layout() for the same axis DOES deep-merge, so TICK LABELS are colored here, once,
# for every chart. Axis titles and annotations cannot be fixed here: plotly keeps neither in
# p$x$layout before the build, and it discards a title's text when a later call gives the title
# only a font. Those are colored where their words are set, through axis_title() and ann_font()
# below. The legend already inherits font, so it is left alone.
themed <- function(p, dark) {
  fg <- if (isTRUE(dark)) "#E6E6E6" else "#212529"
  grid <- if (isTRUE(dark)) "rgba(255,255,255,0.12)" else "rgba(0,0,0,0.10)"
  p %>%
    layout(
      paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
      font = list(color = fg),
      xaxis = list(gridcolor = grid, zerolinecolor = grid, tickfont = list(color = fg)),
      yaxis = list(gridcolor = grid, zerolinecolor = grid, tickfont = list(color = fg)),
      legend = list(orientation = "h", y = -0.2)
    ) %>%
    config(displayModeBar = FALSE)
}

# An axis title that carries the theme color. The text is passed in because plotly drops a
# title's text if a later call names only its font, so it must be set where the words are.
axis_title <- function(text, dark) {
  fg <- if (isTRUE(dark)) "#E6E6E6" else "#212529"
  list(text = text, font = list(color = fg))
}

# The theme's text color, for a chart's own annotations (plotly does not let them inherit it).
ann_font <- function(dark) {
  list(color = if (isTRUE(dark)) "#E6E6E6" else "#212529")
}

empty_plot <- function(text, dark = FALSE) {
  plot_ly() %>%
    layout(annotations = list(text = text, showarrow = FALSE, x = 0.5, y = 0.5, xref = "paper", yref = "paper",
                              font = ann_font(dark)),
           xaxis = list(visible = FALSE), yaxis = list(visible = FALSE)) %>%
    themed(dark)
}

hline <- function(y, color, dash = "dash", width = 1) {
  list(type = "line", xref = "paper", x0 = 0, x1 = 1, yref = "y", y0 = y, y1 = y,
       line = list(color = color, dash = dash, width = width))
}

vline <- function(x, color = "#6C757D") {
  list(type = "line", xref = "x", x0 = x, x1 = x, yref = "paper", y0 = 0, y1 = 1,
       line = list(color = color, dash = "dash", width = 2))
}

# Rows of the subgroup table inside the chosen date range.
visible_rows <- function(a, dates) {
  t <- a$subgroups$time
  if (is.null(dates) || length(dates) < 2 || anyNA(dates)) return(rep(TRUE, length(t)))
  as.Date(t) >= dates[1] & as.Date(t) <= dates[2]
}

# Gray block over the baseline hours.
baseline_shape <- function(d) {
  b <- d[d$baseline, , drop = FALSE]
  if (nrow(b) == 0) return(NULL)
  list(type = "rect", xref = "x", yref = "paper", y0 = 0, y1 = 1,
       x0 = time_text(min(b$time)), x1 = time_text(max(b$time) + 3600),
       fillcolor = "rgba(110,110,110,0.28)", line = list(width = 0), layer = "below")
}

# ---- Plots ---------------------------------------------------------------------------------------

sparkline_plot <- function(a, dark = FALSE) {
  d <- utils::tail(a$subgroups, 48)
  if (nrow(d) == 0) return(empty_plot("no hourly data", dark))
  fg <- if (isTRUE(dark)) "#E6E6E6" else "#212529"
  shapes <- list()
  annotations <- list()
  y_range <- NULL
  if (isTRUE(a$has_limits)) {
    lim <- a$baseline$limits$xbar
    # The band is the baseline mean plus or minus 3 standard errors.
    shapes <- list(
      list(type = "rect", xref = "paper", x0 = 0, x1 = 1, yref = "y",
           y0 = lim$lcl, y1 = lim$ucl,
           fillcolor = "rgba(100,120,150,0.16)", line = list(width = 0), layer = "below"),
      hline(lim$lcl, "rgba(128,128,128,0.75)", "dot"),
      hline(lim$ucl, "rgba(128,128,128,0.75)", "dot")
    )
    label <- function(y, text, anchor) {
      list(x = 1, xref = "paper", xanchor = "right", y = y, yanchor = anchor,
           text = text, showarrow = FALSE, font = list(size = 10, color = fg))
    }
    annotations <- list(label(lim$ucl, "+3 SE", "bottom"), label(lim$lcl, "-3 SE", "top"))
    span <- lim$ucl - lim$lcl
    pad <- if (isTRUE(span > 0)) span * 0.28 else 0.1
    y_range <- c(min(c(d$mean, lim$lcl), na.rm = TRUE) - pad,
                 max(c(d$mean, lim$ucl), na.rm = TRUE) + pad)
  }
  plot_ly(d, x = ~time, y = ~mean, type = "scatter", mode = "lines",
          line = list(color = a$status_color, width = 2),
          text = ~sprintf("%s<br>%.2f C", time_text(time), mean), hoverinfo = "text") %>%
    layout(shapes = shapes, annotations = annotations,
           margin = list(l = 56, r = 8, t = 8, b = 36),
           xaxis = list(title = "", nticks = 3, tickformat = "%b %d",
                        tickfont = list(size = 10, color = fg)),
           yaxis = list(title = axis_title("Hourly mean (\u00B0C)", dark),
                        tickfont = list(size = 10, color = fg),
                        range = y_range),
           paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)", showlegend = FALSE) %>%
    config(displayModeBar = FALSE)
}

# The fridge the lab manager should open first: highest priority among red and amber.
shift_status <- function(list_a) {
  if (length(list_a) == 0) return(NULL)
  action <- list_a[vapply(list_a, function(a) a$status %in% c("red", "amber"), logical(1))]
  if (length(action) == 0) return("Every fridge can be left this shift.")
  ids <- names(action)
  rpns <- vapply(action, function(a) a$rpn, numeric(1))
  top <- action[[ids[order(-rpns, ids)[1]]]]
  latest <- utils::tail(top$readings$temp_c, 1)
  situation <- if (isTRUE(latest > SPEC_HIGH)) {
    "already above 6 \u00B0C"
  } else if (isTRUE(latest < SPEC_LOW)) {
    "already below 1 \u00B0C"
  } else if (top$status == "red") {
    "act this shift"
  } else {
    "watch this shift"
  }
  sprintf("Go to %s first. %s bags, %s.",
          fridge_label(top$fridge_id), format(top$blood_units, big.mark = ","), situation)
}

# One number on the right-hand side of a fridge card. The label and the value
# share a row so five of them stack beside the chart without a second grid.
card_stat <- function(label, value) {
  tags$div(
    class = "d-flex justify-content-between align-items-baseline gap-2",
    tags$span(class = "text-muted", label),
    tags$strong(class = "text-nowrap", value)
  )
}

stat_box <- function(label, value, note, quiet = FALSE, value_class = NULL) {
  tags$div(
    class = "h-100 p-3 border rounded-3 bg-body",
    tags$div(class = "bbm-label", label),
    tags$div(class = paste(if (quiet) "bbm-number-quiet" else "bbm-number", value_class), value),
    tags$div(class = "text-muted small mt-2", note)
  )
}

# ---- Colour rules for a value box --------------------------------------------------------------
# bslib::value_box() renders its value as <p class="value-box-value">, and it has no argument
# for a class on that number. Wrapping the value in a span keeps bslib's own class as well as
# ours, so the box looks the same and only the colour changes. The rules below answer one
# question each - "is this number good news?" - and return NULL, never a colour, when the
# answer is "cannot tell yet". A fridge with no usable baseline limits is neither good nor bad,
# so it keeps the default colour, the same choice the Overview's Average Ppk makes.

CAPABILITY_GAP_GREEN <- 0.10  # |Gap| below this reads as steady; a team-chosen visual guide

# TRUE is green, FALSE is red, NULL is uncoloured.
cap_ok <- function(cpk) if (is.na(cpk)) NULL else cpk >= 1

# Gap is signed and can be negative (Ppk above Cpk). The caption calls a near-zero Gap steady
# without saying which sign is bad, so the magnitude is what matters: -0.29 and +0.29 are the
# same news. This is a judgement the team made, not a formula from the textbook.
gap_ok <- function(gap) if (is.na(gap)) NULL else abs(gap) < CAPABILITY_GAP_GREEN

# The generator's 10 s line is the team's chosen threshold, NOT the chart's own control limit,
# so the Capability card and the Overview box never disagree.
generator_ok <- function(value) if (is.na(value)) NULL else value <= 10

# A count of flagged tests: zero is the good case.
zero_ok <- function(n) if (is.na(n)) NULL else n == 0

# Wrap a box's value for display, colouring it by the rule's answer. ok = NULL leaves it plain.
box_value <- function(value, ok) {
  cls <- if (is.null(ok)) NULL else if (isTRUE(ok)) "bbm-ok" else "bbm-over"
  if (is.null(cls)) value else tags$span(class = cls, value)
}

xbar_plot <- function(a, keep, zone_lines, dark) {
  if (!a$has_limits) return(empty_plot(a$baseline$message, dark))
  d <- a$subgroups
  d$min_test <- a$xbar_min_test
  d <- d[keep, , drop = FALSE]
  if (nrow(d) == 0) return(empty_plot("no hours in this date range", dark))
  lim <- a$baseline$limits$xbar
  mean_val <- mean(d$mean, na.rm = TRUE)

  p <- plot_ly() %>%
    add_lines(x = d$time, y = d$mean, line = list(color = "rgba(120,120,120,0.8)", width = 1),
              hoverinfo = "skip", showlegend = FALSE)
  ok <- d[is.na(d$min_test), , drop = FALSE]
  p <- p %>% add_markers(x = ok$time, y = ok$mean, marker = list(color = "#6C757D", size = 5),
                         text = sprintf("%s<br>Mean %.2f C", time_text(ok$time), ok$mean),
                         hoverinfo = "text", name = "Hourly mean")
  for (k in sort(unique(stats::na.omit(d$min_test)))) {
    f <- d[!is.na(d$min_test) & d$min_test == k, , drop = FALSE]
    p <- p %>% add_markers(
      x = f$time, y = f$mean, marker = list(color = TEST_COLORS[k], size = 10, line = list(color = "#FFFFFF", width = 1)),
      text = sprintf("%s<br>Mean %.2f C<br>Test %d: %s", time_text(f$time), f$mean, k, a$tests[[k]]$meaning),
      hoverinfo = "text", name = paste("Test", k)
    )
  }
  line_x <- range(d$time)
  add_ref <- function(p, y, name, dash, color) {
    p %>% add_lines(x = line_x, y = c(y, y), name = name, line = list(color = color, dash = dash, width = 1.5),
                    text = sprintf("%s %.3f C", name, y), hoverinfo = "text")
  }
  p <- p %>%
    add_lines(x = line_x, y = c(mean_val, mean_val), name = "Dataset Mean", line = list(color = "black", dash = "dot", width = 1.5),
              text = sprintf("Dataset Mean %.3f C", mean_val), hoverinfo = "text") %>%
    add_ref(lim$ucl, "UCL", "dash", "#444444") %>%
    add_ref(lim$center, "Center", "solid", "#444444") %>%
    add_ref(lim$lcl, "LCL", "dash", "#444444")
  if (isTRUE(zone_lines)) {
    for (z in c(lim$zone1, lim$zone2)) {
      p <- p %>%
        add_lines(x = line_x, y = rep(lim$center + z, 2), line = list(color = "rgba(90,90,90,0.5)", dash = "dot", width = 1),
                  hoverinfo = "skip", showlegend = FALSE) %>%
        add_lines(x = line_x, y = rep(lim$center - z, 2), line = list(color = "rgba(90,90,90,0.5)", dash = "dot", width = 1),
                  hoverinfo = "skip", showlegend = FALSE)
    }
  }

  bands <- zone_bands(lim)
  alpha <- c(0.05, 0.11, 0.18)[bands$depth]
  shapes <- lapply(seq_len(nrow(bands)), function(i) {
    list(type = "rect", xref = "paper", x0 = 0, x1 = 1, yref = "y", y0 = bands$y0[i], y1 = bands$y1[i],
         fillcolor = sprintf("rgba(100,120,150,%.2f)", alpha[i]), line = list(width = 0), layer = "below")
  })
  base <- baseline_shape(d)
  if (!is.null(base)) shapes <- c(shapes, list(base))

  p %>%
    layout(shapes = shapes, yaxis = list(title = axis_title("Hourly mean (\u00B0C)", dark)), xaxis = list(title = ""),
           title = list(text = "X-bar chart. Limits are the baseline mean \u00b1 3 standard errors. Gray marks the first 48 hours.", font = list(size = 14, color = ann_font(dark)$color))) %>%
    themed(dark)
}

range_plot <- function(a, keep, dark) {
  if (!a$has_limits) return(empty_plot(a$baseline$message, dark))
  d <- a$subgroups
  d$flag <- a$range_flagged
  d <- d[keep, , drop = FALSE]
  if (nrow(d) == 0) return(empty_plot("no hours in this date range", dark))
  lim <- a$baseline$limits$range
  line_x <- range(d$time)
  f <- d[d$flag, , drop = FALSE]
  ok <- d[!d$flag, , drop = FALSE]

  p <- plot_ly() %>%
    add_lines(x = d$time, y = d$range, line = list(color = "rgba(120,120,120,0.8)", width = 1),
              hoverinfo = "skip", showlegend = FALSE) %>%
    add_markers(x = ok$time, y = ok$range, marker = list(color = "#6C757D", size = 5),
                text = sprintf("%s<br>Range %.2f C", time_text(ok$time), ok$range), hoverinfo = "text", name = "Hourly range")
  if (nrow(f) > 0) {
    p <- p %>% add_markers(x = f$time, y = f$range, marker = list(color = TEST_COLORS[1], size = 10),
                           text = sprintf("%s<br>Range %.2f C<br>Test 1: %s", time_text(f$time), f$range, a$range_test$meaning),
                           hoverinfo = "text", name = "Test 1")
  }
  for (spec in list(list("UCL", lim$ucl, "dash"), list("Center", lim$center, "solid"), list("LCL", lim$lcl, "dash"))) {
    p <- p %>% add_lines(x = line_x, y = rep(spec[[2]], 2), name = spec[[1]],
                         line = list(color = "#444444", dash = spec[[3]], width = 1.5),
                         text = sprintf("%s %.3f C", spec[[1]], spec[[2]]), hoverinfo = "text")
  }
  base <- baseline_shape(d)
  p %>%
    layout(shapes = if (is.null(base)) list() else list(base),
           yaxis = list(title = axis_title("Hourly range (\u00B0C)", dark)), xaxis = list(title = ""),
           title = list(text = "Range chart", font = list(size = 14, color = ann_font(dark)$color))) %>%
    themed(dark)
}

# The standard deviation (s) chart. Same shape as the range chart, and like it
# this runs test 1 only. Its flags are drawn here and nowhere else: they do not
# reach the violations table, the badge, the RPN or units_at_risk.
sd_plot <- function(a, keep, dark) {
  if (!a$has_limits) return(empty_plot(a$baseline$message, dark))
  d <- a$subgroups
  d$flag <- a$sd_flagged
  d <- d[keep, , drop = FALSE]
  if (nrow(d) == 0) return(empty_plot("no hours in this date range", dark))
  lim <- a$baseline$limits$sd
  line_x <- range(d$time)
  f <- d[d$flag, , drop = FALSE]
  ok <- d[!d$flag, , drop = FALSE]

  p <- plot_ly() %>%
    add_lines(x = d$time, y = d$sd, line = list(color = "rgba(120,120,120,0.8)", width = 1),
              hoverinfo = "skip", showlegend = FALSE) %>%
    add_markers(x = ok$time, y = ok$sd, marker = list(color = "#6C757D", size = 5),
                text = sprintf("%s<br>s %.3f C", time_text(ok$time), ok$sd), hoverinfo = "text", name = "Hourly s")
  if (nrow(f) > 0) {
    p <- p %>% add_markers(x = f$time, y = f$sd, marker = list(color = TEST_COLORS[1], size = 10),
                           text = sprintf("%s<br>s %.3f C<br>Test 1: %s", time_text(f$time), f$sd, a$sd_test$meaning),
                           hoverinfo = "text", name = "Test 1")
  }
  for (spec in list(list("UCL", lim$ucl, "dash"), list("Center", lim$center, "solid"), list("LCL", lim$lcl, "dash"))) {
    p <- p %>% add_lines(x = line_x, y = rep(spec[[2]], 2), name = spec[[1]],
                         line = list(color = "#444444", dash = spec[[3]], width = 1.5),
                         text = sprintf("%s %.3f C", spec[[1]], spec[[2]]), hoverinfo = "text")
  }
  base <- baseline_shape(d)
  p %>%
    layout(shapes = if (is.null(base)) list() else list(base),
           yaxis = list(title = axis_title("Hourly standard deviation (\u00B0C)", dark), autosize = TRUE),
           xaxis = list(title = ""),
           title = list(text = "Standard deviation chart (dispersion; limits frozen)", font = list(size = 14, color = ann_font(dark)$color))) %>%
    themed(dark)
}

histogram_plot <- function(a, dark) {
  if (!a$has_limits) return(empty_plot(a$baseline$message, dark))
  # A wash between the spec limits, so the window reads as a place. The three
  # lines stay where they were. This does not change a count or an index.
  band <- list(type = "rect", xref = "x", x0 = SPEC_LOW, x1 = SPEC_HIGH, yref = "paper", y0 = 0, y1 = 1,
               fillcolor = "rgba(46,158,107,0.14)", line = list(width = 0), layer = "below")
  shapes <- list(band, vline(SPEC_LOW, "#444444"), vline(TARGET_TEMP, "#6C757D"), vline(SPEC_HIGH, "#444444"))
  notes <- list(
    list(x = SPEC_LOW, text = "1 \u00B0C (lower spec)"),
    list(x = TARGET_TEMP, text = "3.5 \u00B0C (target)"),
    list(x = SPEC_HIGH, text = "6 \u00B0C (upper spec)")
  )
  notes <- lapply(notes, function(n) c(n, list(y = 1, yref = "paper", xref = "x", showarrow = FALSE,
                                                  yanchor = "bottom", font = ann_font(dark))))
  plot_ly(x = a$base_readings, type = "histogram", nbinsx = 30, marker = list(color = "#6C757D"),
          hovertemplate = "%{x} C: %{y} readings<extra></extra>") %>%
    layout(shapes = shapes, annotations = notes,
           xaxis = list(title = axis_title("Baseline temperature (\u00B0C)", dark), range = c(0.5, 6.5)),
           yaxis = list(title = axis_title("Readings", dark)), showlegend = FALSE,
           margin = list(t = 40)) %>%
    themed(dark)
}

rolling_plot <- function(a, dark) {
  if (length(a$rolling_ppk) == 0) return(empty_plot("need at least 24 hours of readings", dark))
  # The line at 1.0 is the same cutoff the Cpk box uses. The axis starts at 0
  # when the series is positive, so the line stays on the chart.
  y <- a$rolling_ppk
  finite <- y[is.finite(y)]
  if (length(finite) == 0) {
    y_range <- c(0, 2)
  } else {
    lo <- min(0, finite)
    hi <- max(1, finite)
    pad <- max((hi - lo) * 0.06, 0.15)
    y_range <- c(lo, hi + pad)
  }
  plot_ly(x = a$rolling_time, y = a$rolling_ppk, type = "scatter", mode = "lines",
          line = list(color = "#444444", width = 2),
          text = sprintf("%s<br>Ppk %s", time_text(a$rolling_time), formatC(a$rolling_ppk, format = "f", digits = 2)),
          hoverinfo = "text") %>%
    layout(shapes = list(hline(1, "#2E9E6B", "dash", 1.5)),
           annotations = list(list(x = 1, xref = "paper", y = 1, yref = "y", text = "1.0",
                                   showarrow = FALSE, xanchor = "right", yanchor = "bottom",
                                   font = ann_font(dark))),
           yaxis = list(title = axis_title("Rolling 24-hour Ppk", dark), range = y_range),
           xaxis = list(title = ""), showlegend = FALSE) %>%
    themed(dark)
}

# Bags by blood type for one fridge. Display only: the counts come from the inventory
# sheet and the at-risk split from bloodtype_table(), which divides by the fridge's own
# total. The colors are FIXED to the meaning, not to the fridge's badge: at risk is always
# red and within spec is always green, the same red and green the status badges use
# ("Act this shift" #D64045, "Leave it" #2E9E6B). Tying at-risk to the status color made
# a green fridge draw its at-risk bags green, which read as safe when the bags were not.
# Sorted commonest first, which bloodtype_table() already does.
bloodtype_plot <- function(bt, dark) {
  if (nrow(bt) == 0) {
    return(empty_plot("No inventory rows for this fridge.<br>Add blood_type to the inventory file.", dark))
  }
  at_risk <- bt$units_at_risk
  safe <- bt$blood_units - at_risk
  plot_ly() %>%
    add_bars(x = ~safe, y = ~bt$blood_type, orientation = "h", name = "Within spec",
             marker = list(color = "#2E9E6B"),
             text = ~sprintf("%d bags", round(safe)), textposition = "inside",
             hovertemplate = "%{y}: %{x} bags within spec<extra></extra>") %>%
    add_bars(x = ~at_risk, y = ~bt$blood_type, orientation = "h", name = "At risk",
             marker = list(color = "#D64045"),
             text = ~ifelse(at_risk > 0, sprintf("%d at risk", round(at_risk)), ""),
             textposition = "inside",
             hovertemplate = "%{y}: %{x} bags at risk<extra></extra>") %>%
    layout(barmode = "stack",
           xaxis = list(title = axis_title("Red-cell bags", dark),
                        tickfont = list(color = ann_font(dark)$color),
                        gridcolor = if (isTRUE(dark)) "rgba(255,255,255,0.12)" else "rgba(0,0,0,0.10)"),
           yaxis = list(title = "", categoryorder = "total ascending",
                        tickfont = list(color = ann_font(dark)$color)),
           legend = list(orientation = "h", y = -0.25),
           margin = list(t = 10)) %>%
    config(displayModeBar = FALSE)
}

generator_plots <- function(g, dark) {
  lim <- g$limits
  idx <- seq_len(g$n)
  x <- g$x
  f <- g$flagged
  is_flag <- idx %in% f
  ind <- plot_ly() %>%
    add_lines(x = idx, y = x, line = list(color = "rgba(120,120,120,0.8)", width = 1), hoverinfo = "skip", showlegend = FALSE) %>%
    add_markers(x = idx[!is_flag], y = x[!is_flag], marker = list(color = "#6C757D", size = 6),
                text = sprintf("%s<br>%.1f s", g$labels[!is_flag], x[!is_flag]), hoverinfo = "text", name = "Transfer time")
  if (length(f) > 0) {
    ind <- ind %>% add_markers(x = idx[f], y = x[f], marker = list(color = TEST_COLORS[1], size = 10),
                               text = sprintf("%s<br>%.1f s<br>Outside the limits", g$labels[f], x[f]),
                               hoverinfo = "text", name = "Test 1")
  }
  shapes <- list(hline(10, "#444444", "solid", 2))
  if (!is.na(lim$ucl)) {
    shapes <- c(shapes, list(hline(lim$center, "#888888", "solid"), hline(lim$ucl, "#888888", "dash"), hline(lim$lcl, "#888888", "dash")))
  }
  ind <- ind %>%
    layout(shapes = shapes,
           annotations = list(list(x = 1, xref = "paper", y = 10, yref = "y", text = "10 s threshold", showarrow = FALSE,
                                   xanchor = "right", yanchor = "bottom", font = ann_font(dark))),
           xaxis = list(title = axis_title("Test number (in date order)", dark)),
           yaxis = list(title = axis_title("Transfer time (s)", dark)),
           title = list(text = "Individuals chart", font = list(size = 14, color = ann_font(dark)$color))) %>%
    themed(dark)

  has_mr <- !is.na(g$moving_range)
  mr <- plot_ly() %>%
    add_lines(x = idx[has_mr], y = g$moving_range[has_mr], line = list(color = "rgba(120,120,120,0.8)", width = 1),
              hoverinfo = "skip", showlegend = FALSE) %>%
    add_markers(x = idx[has_mr], y = g$moving_range[has_mr], marker = list(color = "#6C757D", size = 6),
                text = sprintf("%s<br>Moving range %.1f s", g$labels[has_mr], g$moving_range[has_mr]),
                hoverinfo = "text", name = "Moving range")
  mr_shapes <- if (is.na(lim$mr_ucl)) list() else list(hline(lim$mr_center, "#888888", "solid"),
                                                       hline(lim$mr_ucl, "#888888", "dash"), hline(lim$mr_lcl, "#888888", "dash"))
  mr <- mr %>%
    layout(shapes = mr_shapes, xaxis = list(title = axis_title("Test number (in date order)", dark)),
           yaxis = list(title = axis_title("Moving range (s)", dark)), showlegend = FALSE,
           title = list(text = "Moving-range chart", font = list(size = 14, color = ann_font(dark)$color))) %>%
    themed(dark)
  list(individuals = ind, moving_range = mr)
}

# ---- Capability page pieces ----------------------------------------------------------------------
# Display only. Every number is already on the analysis or on generator_stats().

capability_sentence <- function(a) {
  if (a$capable_sentence %in% CAPABLE_SENTENCES) {
    paste0(fridge_label(a$fridge_id), " is ", a$capable_sentence, ".")
  } else {
    paste0(fridge_label(a$fridge_id), ": ", a$capable_sentence)
  }
}

capability_verdict_card <- function(a) {
  htmltools::tagAppendAttributes(
    bslib::card(
      fill = FALSE,
      class = "bbm-cap",
      bslib::card_header(tags$h4(class = "mb-0", capability_sentence(a))),
      bslib::layout_columns(
        fill = FALSE, col_widths = bslib::breakpoints(sm = 12, md = 4),
        bslib::value_box("Cpk (short-term sigma)", box_value(fmt_num(a$cpk, 2), cap_ok(a$cpk)),
          tags$small("Hour to hour room inside 1\u20136 \u00B0C. Above 1.0 is room to spare.")),
        bslib::value_box("Ppk (overall sigma)", box_value(fmt_num(a$ppk, 2), cap_ok(a$ppk)),
          tags$small("The same room across the whole baseline, drift included.")),
        bslib::value_box("Gap (Cpk minus Ppk)", box_value(fmt_num(a$gap, 2), gap_ok(a$gap)),
          tags$small("Near zero is steady. A stability signal, not a score."))
      )
    ),
    style = sprintf("--bbm-edge:%s;", capable_edge(a$capable_sentence))
  )
}

capability_notes_card <- function(a) {
  lag_text <- if (is.na(a$lag1)) "Lag-1 autocorrelation of the baseline: \u2014." else
    sprintf("Lag-1 autocorrelation of the baseline readings: %.2f. The limits assume independent readings; this is a limitation, not an adjustment.", a$lag1)
  bslib::card(
    fill = FALSE,
    class = "mb-3",
    tags$details(
      class = "small text-muted",
      tags$summary("How to read these numbers"),
      tags$p(class = "mt-2 mb-2",
             paste("Cpk is the room left if this fridge keeps holding temperature the way it",
                   "has been holding it hour to hour. Above 1.0 is room to spare; below 1.0",
                   "it cannot reliably stay in spec.")),
      tags$p(class = "mb-2",
             paste("Ppk is the same room measured across the whole baseline, drift and",
                   "hour-to-hour shifts included. This is the long-run number.")),
      tags$p(class = "mb-2",
             paste("The gap is a stability signal, not a score. Near zero means the fridge is",
                   "steady. Clearly positive means it holds temperature within an hour but",
                   "wanders between hours, which is a stability problem rather than a",
                   "capability problem.")),
      tags$p(class = "mb-2", lag_text),
      tags$p(class = "mb-0",
             paste("This bar's color is the baseline verdict. The Overview badge looks only",
                   "at the last day, so a fridge can need action today and still read capable here."))
    )
  )
}

capability_generator_card <- function(gs) {
  if (is.null(gs)) {
    return(bslib::card(
      fill = FALSE,
      class = "mb-3",
      tags$h5(class = "mb-1", "Backup generator"),
      tags$p(class = "text-muted small mb-0",
             "No backup generator log loaded. Add one on the Data page to see the backup power statistics here.")
    ))
  }
  bslib::card(
    fill = FALSE,
    class = "mb-3",
    tags$h5(class = "mb-1", "Backup generator"),
    tags$p(class = "text-muted small",
           paste("Seconds from a mains outage until backup power carries the load.",
                 "The 10 s line is a threshold the team chose, not a control limit.")),
    bslib::layout_columns(
      fill = FALSE, col_widths = bslib::breakpoints(sm = 12, md = 4),
      bslib::value_box("Last transfer", box_value(fmt_num(gs$last, 1), generator_ok(gs$last)),
                       tags$small("seconds, from the most recent test")),
      bslib::value_box("Typical transfer", box_value(fmt_num(gs$typical, 1), generator_ok(gs$typical)),
                       tags$small("seconds, the center of the chart")),
      bslib::value_box("Tests beyond the limits", box_value(sprintf("%d", gs$beyond), zero_ok(gs$beyond)),
                       tags$small(sprintf("of %d tests run", gs$n)))
    )
  )
}

# The site's generator is one log, not a fridge. This value is the extra choice
# on Fridge and Generator Detail.
GENERATOR_CHOICE <- "generator"

docs_section <- function(title, subtitle, ...) {
  tags$details(
    class = "bbm-docsec",
    tags$summary(
      tags$span(
        class = "bbm-docsec-copy",
        tags$span(class = "bbm-docsec-title", title),
        tags$span(class = "bbm-docsec-sub", subtitle)
      )
    ),
    tags$div(class = "bbm-docsec-body", ...)
  )
}

# One equation, written the way the function in app/R/ computes it.
docs_equation <- function(title, formula, note, wide = FALSE) {
  tags$div(
    class = if (wide) "bbm-eq bbm-wide" else "bbm-eq",
    tags$span(title),
    tags$pre(class = "bbm-formula", formula),
    tags$p(note)
  )
}

docs_file <- function(name, rows, note, href) {
  tags$div(
    class = "bbm-file",
    tags$span(name),
    tags$strong(rows),
    tags$p(note),
    tags$a(href = href, target = "_blank", rel = "noopener", "Open the file")
  )
}

docs_table <- function(headers, rows, numeric = FALSE) {
  tags$table(
    class = if (numeric) "bbm-table bbm-table-nums" else "bbm-table",
    tags$thead(tags$tr(lapply(headers, tags$th))),
    tags$tbody(lapply(rows, function(row) tags$tr(lapply(row, tags$td))))
  )
}

docs_page <- function() {
  tags$div(
    id = "bbm-docs",
    tags$style(HTML("
      #bbm-docs { width: min(1240px, 100%); margin-left: auto; margin-right: auto; }
      .bbm-docs-hero {
        background: var(--bs-body-bg);
        border: 1px solid var(--bs-border-color);
        border-radius: 14px;
        padding: 22px 24px 18px;
        box-shadow: rgba(20, 22, 28, 0.05) 0 1px 2px, rgba(20, 22, 28, 0.05) 0 6px 18px;
        margin-bottom: 16px;
      }
      .bbm-docs-kicker {
        font-size: 0.72rem; letter-spacing: 0.12em; text-transform: uppercase;
        color: var(--bs-secondary-color); margin: 0 0 8px;
      }
      .bbm-docs-hero h2 {
        font-size: 1.9rem; font-weight: 650; letter-spacing: -0.03em;
        margin: 0 0 10px; line-height: 1.15;
      }
      .bbm-docs-lead { font-size: 1.05rem; margin: 0 0 16px; }
      .bbm-docs-facts { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 14px; }
      .bbm-docs-fact {
        background: var(--bs-tertiary-bg); border: 1px solid var(--bs-border-color);
        border-radius: 10px; padding: 10px 12px;
      }
      .bbm-docs-fact span {
        display: block; font-size: 0.68rem; letter-spacing: 0.08em; text-transform: uppercase;
        color: var(--bs-secondary-color); margin-bottom: 3px;
      }
      .bbm-docs-fact strong { font-weight: 600; font-size: 0.95rem; }
      .bbm-docs-links { display: flex; flex-wrap: wrap; gap: 8px; }
      .bbm-docs-links a {
        display: inline-block; border: 1px solid var(--bs-border-color); border-radius: 999px;
        padding: 5px 12px; font-size: 0.85rem; font-weight: 600; color: #B3202A;
        text-decoration: none; background: var(--bs-body-bg);
      }
      [data-bs-theme='dark'] .bbm-docs-links a { color: #ff8a8d; }
      .bbm-docs-bar {
        display: flex; justify-content: space-between; align-items: center;
        margin: 2px 2px 12px; color: var(--bs-secondary-color); font-size: 0.92rem;
      }
      .bbm-docs-expand {
        border: 1px solid var(--bs-border-color); background: var(--bs-body-bg);
        color: var(--bs-body-color); border-radius: 8px; padding: 4px 12px; font-size: 0.85rem;
      }
      .bbm-docsec {
        background: var(--bs-body-bg); border: 1px solid var(--bs-border-color);
        border-radius: 14px;
        box-shadow: rgba(20, 22, 28, 0.05) 0 1px 2px, rgba(20, 22, 28, 0.05) 0 6px 18px;
        margin-bottom: 12px;
      }
      .bbm-docsec summary {
        list-style: none; cursor: pointer; display: flex; align-items: center;
        gap: 16px; padding: 16px 18px 16px 22px;
      }
      .bbm-docsec summary::-webkit-details-marker { display: none; }
      .bbm-docsec-copy { flex: 1 1 auto; }
      .bbm-docsec-title { display: block; font-weight: 700; font-size: 1.05rem; }
      .bbm-docsec-sub { display: block; color: var(--bs-secondary-color); font-size: 0.92rem; margin-top: 2px; }
      .bbm-docsec summary::after {
        content: '+'; width: 28px; height: 28px; border: 1px solid var(--bs-border-color);
        border-radius: 999px; display: grid; place-items: center;
        color: var(--bs-secondary-color); flex: none; font-size: 1.1rem; line-height: 1;
      }
      .bbm-docsec[open] summary::after { content: '\\2212'; }
      .bbm-docsec-body { padding: 0 22px 16px 22px; }
      .bbm-docsec-body h3 { font-size: 1.02rem; margin: 18px 0 8px; }
      .bbm-docsec-body h3:first-child { margin-top: 4px; }
      .bbm-team {
        background: var(--bs-body-bg); border: 1px solid var(--bs-border-color);
        border-radius: 14px; padding: 16px 22px 18px;
        box-shadow: rgba(20, 22, 28, 0.05) 0 1px 2px, rgba(20, 22, 28, 0.05) 0 6px 18px;
        margin-bottom: 16px;
      }
      .bbm-names { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-top: 12px; }
      .bbm-names span {
        background: var(--bs-tertiary-bg); border: 1px solid var(--bs-border-color);
        border-radius: 10px; padding: 14px 12px; font-weight: 600; text-align: center;
      }
      .bbm-steps { list-style: none; padding: 0; margin: 0; }
      .bbm-steps li {
        display: grid; grid-template-columns: 36px 1fr; gap: 14px; align-items: start;
        padding: 14px 0; border-top: 1px solid var(--bs-border-color);
      }
      .bbm-steps li:first-child { border-top: 0; padding-top: 0; }
      .bbm-steps li::before {
        content: counter(bbm-step); counter-increment: bbm-step;
        width: 36px; height: 36px; border-radius: 999px; background: #B3202A; color: #fff;
        display: grid; place-items: center; font-weight: 700;
      }
      .bbm-steps { counter-reset: bbm-step; }
      .bbm-steps strong { display: block; margin-bottom: 2px; }
      .bbm-eqs, .bbm-files, .bbm-checks { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
      .bbm-files { grid-template-columns: repeat(3, 1fr); }
      .bbm-checks-4 { grid-template-columns: repeat(4, 1fr); }
      .bbm-eq, .bbm-file, .bbm-check {
        background: var(--bs-tertiary-bg); border: 1px solid var(--bs-border-color);
        border-radius: 12px; padding: 14px 16px;
      }
      .bbm-eq span, .bbm-file span, .bbm-check span {
        display: block; font-size: 0.68rem; letter-spacing: 0.08em; text-transform: uppercase;
        color: var(--bs-secondary-color); margin-bottom: 6px;
      }
      .bbm-formula {
        font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
        font-size: 0.86rem; line-height: 1.45; white-space: pre-wrap;
        background: var(--bs-body-bg); border-radius: 8px; padding: 10px 12px; margin: 0 0 8px;
      }
      .bbm-eq p, .bbm-file p, .bbm-check p { margin: 0; font-size: 0.92rem; }
      .bbm-file strong { display: block; font-size: 1.35rem; font-weight: 650; letter-spacing: -0.02em; margin-bottom: 4px; }
      .bbm-file a { color: #B3202A; font-weight: 600; font-size: 0.88rem; }
      [data-bs-theme='dark'] .bbm-file a { color: #ff8a8d; }
      .bbm-table { width: 100%; border-collapse: collapse; font-size: 0.92rem; margin: 0 0 8px; }
      .bbm-table th, .bbm-table td {
        text-align: left; padding: 8px 10px; border-bottom: 1px solid var(--bs-border-color);
        vertical-align: top;
      }
      .bbm-table th {
        font-size: 0.72rem; letter-spacing: 0.06em; text-transform: uppercase;
        color: var(--bs-secondary-color); font-weight: 600;
      }
      .bbm-table-nums td:last-child, .bbm-table-nums th:last-child {
        text-align: right; white-space: nowrap; width: 1%; font-variant-numeric: tabular-nums;
      }
      .bbm-wide { grid-column: 1 / -1; }
      @media (max-width: 800px) {
        .bbm-docs-facts, .bbm-names, .bbm-eqs, .bbm-files, .bbm-checks, .bbm-checks-4 { grid-template-columns: 1fr; }
      }
    ")),
    tags$script(HTML("
      function bbmDocsToggle(btn) {
        var root = document.getElementById('bbm-docs');
        var items = root.querySelectorAll('details');
        var openThem = Array.prototype.some.call(items, function (d) { return !d.open; });
        Array.prototype.forEach.call(items, function (d) { d.open = openThem; });
        btn.textContent = openThem ? 'Collapse all' : 'Expand all';
      }
    ")),
    tags$div(
      class = "bbm-docs-hero",
      tags$p(class = "bbm-docs-kicker",
             "Project documentation \u00b7 SYSEN 5300 Six Sigma Hackathon \u00b7 Keep It Cool"),
      tags$h2("Bank of Bloody Mary"),
      tags$p(class = "bbm-docs-lead",
             paste("Tells a blood-bank operations manager which refrigerator to service,",
                   "evacuate, or leave before the next shift, so stored red cells stay within",
                   "1\u20136 \u00B0C. The screen only displays numbers computed in the statistics code.",
                   "Red means act this shift, amber means watch, and green means leave it.")),
      tags$div(
        class = "bbm-docs-facts",
        tags$div(class = "bbm-docs-fact", tags$span("User"), tags$strong("Blood-bank operations manager")),
        tags$div(class = "bbm-docs-fact", tags$span("Inputs"),
                 tags$strong("Fridge temperature recordings the lab already logs")),
        tags$div(class = "bbm-docs-fact", tags$span("Data"), tags$strong("Synthetic. Six fridges, one week"))
      ),
      tags$div(
        class = "bbm-docs-links",
        tags$a(href = "https://github.com/rubberduckysmiles/Rwedoneyet",
               target = "_blank", rel = "noopener", "GitHub repository"),
        tags$a(href = "https://github.com/rubberduckysmiles/Rwedoneyet/blob/main/README.md",
               target = "_blank", rel = "noopener", "README"),
        tags$a(href = "https://github.com/rubberduckysmiles/Rwedoneyet/blob/main/data/README.md",
               target = "_blank", rel = "noopener", "Data codebook")
      )
    ),
    tags$div(
      class = "bbm-team",
      tags$span(class = "bbm-docsec-title", "The Team"),
      tags$span(class = "bbm-docsec-sub", "Keep It Cool"),
      tags$div(
        class = "bbm-names",
        tags$span("Hannah Brine"),
        tags$span("Sue Cho"),
        tags$span("Tanya Schilling")
      )
    ),
    tags$div(
      class = "bbm-docs-bar",
      tags$span("Click a section to expand it."),
      tags$button(type = "button", class = "bbm-docs-expand",
                  onclick = "bbmDocsToggle(this)", "Expand all")
    ),
    docs_section(
      "How to use",
      "Load a dataset, read each fridge, then act on the risk priority number",
      tags$ol(
        class = "bbm-steps",
        tags$li(
          tags$div(
            tags$strong("Data."),
            "From the Overview, load an example dataset. General is the planted week. Dataset 2 is ordinary noise. Dataset 1 is the mixed set. The Data page has the same picker, and it can take three files the lab uploads."
          )
        ),
        tags$li(
          tags$div(
            tags$strong("Fridge monitoring."),
            paste("Check each fridge's calculated statistics: the badge, the bags, Ppk, and the",
                  "hourly mean chart. Open Fridge and Generator Detail for the X-bar chart, the",
                  "range chart, the standard deviation chart, the blood types, and the flagged hours.",
                  "Zone lines mark 1 and 2 standard errors. They are not control limits. The last",
                  "choice in that dropdown is the backup generator, one log for the whole plant.",
                  "Open Capability for that fridge's sentence, Cpk, Ppk, and the gap.")
          )
        ),
        tags$li(
          tags$div(
            tags$strong("Take action."),
            paste("Use the risk priority number to decide which fridge to repair, evacuate, or leave.",
                  "The cards are already in that order. Red means act this shift. Amber means watch.",
                  "Green means leave it.")
          )
        )
      )
    ),
    docs_section(
      "Statistical Methods",
      "The equations the statistics code already uses",
      tags$p(paste("Each hour is a subgroup of 4 temperatures. Limits are frozen from the first",
                   "48 hours. Eight special-cause tests run on the X-bar chart. Test 1 also runs",
                   "on the range chart, and test 1 also runs on the standard deviation chart.")),
      tags$div(
        class = "bbm-eqs",
        docs_equation(
          "Sigma short",
          "sigma short = sqrt(mean of the within-hour sample variances)\neach variance divides by n - 1, and n = 4",
          "First 48 hours only. A missing variance makes sigma short missing."
        ),
        docs_equation(
          "Sigma overall",
          "sigma overall = sd(every baseline reading)\nthe divisor is N - 1",
          "This is the spread of the readings themselves, not the spread inside each hour."
        ),
        docs_equation(
          "X-bar limits",
          "center = grand mean of the baseline\nSE = sigma short / sqrt(4)\nLCL = center - 3 * SE\nUCL = center + 3 * SE",
          "SE is the standard error of an hourly mean."
        ),
        docs_equation(
          "Range chart",
          "center = d2 * sigma short\nUCL = (d2 + 3 * d3) * sigma short\nLCL = max(0, (d2 - 3 * d3) * sigma short)",
          "d2 is the mean range of n standard normals and d3 is its standard deviation. Both are integrals of the ptukey tail, not a printed table. A range cannot be negative, so the lower limit stays at 0."
        ),
        docs_equation(
          "Standard deviation chart",
          paste0(
            "c4 = sqrt(2 / (n - 1)) * Gamma(n/2) / Gamma((n - 1) / 2)\n",
            "B5 = max(0, c4 - 3 * sqrt(1 - c4^2))\n",
            "B6 = c4 + 3 * sqrt(1 - c4^2)\n",
            "center = c4 * sigma short\n",
            "LCL = B5 * sigma short\n",
            "UCL = B6 * sigma short"
          ),
          "Display only. A flag here is drawn and then stops. It does not enter the badge, the risk priority number, the bags at risk, or the violations table.",
          wide = TRUE
        ),
        docs_equation(
          "Cpk, Ppk, and the gap",
          paste0(
            "distance = min(6 - mean, mean - 1)\n",
            "Cpk = distance / (3 * sigma short)\n",
            "Ppk = distance / (3 * sigma overall)\n",
            "gap = Cpk - Ppk"
          ),
          "Above 1.0, the index has room inside 1 to 6 \u00B0C. If a sigma is 0, that index is missing. It is never infinity."
        ),
        docs_equation(
          "Rolling Ppk",
          "rolling Ppk = Ppk of the latest 96 readings\nboth sigmas in that window are that window's own sd",
          "96 readings is 24 hours at one reading every 15 minutes. A window with sd 0 gives a missing index."
        ),
        docs_equation(
          "Lag-1 autocorrelation",
          "lag-1 = cor(x[1:(N - 1)], x[2:N])",
          "Printed on the capability page. It is not used to widen the limits.",
          wide = TRUE
        ),
        docs_equation(
          "Individuals and moving range",
          paste0(
            "MR = abs(x[i] - x[i - 1])\n",
            "sigma = mean(MR) / d2\n",
            "individuals center = mean(x)\n",
            "individuals limits = center +/- 3 * sigma\n",
            "MR center = mean(MR)\n",
            "MR UCL = ((d2 + 3 * d3) / d2) * mean(MR)\n",
            "MR LCL = max(0, ((d2 - 3 * d3) / d2) * mean(MR))"
          ),
          "d2 and d3 are for n = 2, because each day has one transfer time. The solid line at 10 seconds is a threshold the team chose. It is not this chart's control limit.",
          wide = TRUE
        ),
        docs_equation(
          "Hours to a spec limit",
          paste0(
            "line = lm(hourly mean ~ hour), after the baseline\n",
            "last = the line at the latest hour\n",
            "hours = 0 if last is outside 1 to 6\n",
            "hours = (6 - last) / slope if the slope is positive\n",
            "hours = (1 - last) / slope if the slope is negative"
          ),
          "A flat line, or a line heading back inside the spec, is no crossing. Fewer than 3 hourly means leaves the hours missing. The fridge card does not print this number. It still sets urgency.",
          wide = TRUE
        ),
        docs_equation(
          "Risk priority number",
          "RPN = severity * occurrence * urgency\neach score is a whole number from 1 to 10",
          "Severity counts bags. Occurrence is the worst signal on the whole chart after the baseline. Urgency comes from the hours above.",
          wide = TRUE
        )
      ),
      tags$h3("Severity, from the bag count"),
      docs_table(
        c("Bags in the fridge", "Score"),
        list(
          c("0", "1"), c("1 to 5", "2"), c("6 to 15", "3"), c("16 to 30", "4"),
          c("31 to 50", "5"), c("51 to 75", "6"), c("76 to 100", "7"),
          c("101 to 150", "8"), c("151 to 200", "9"), c("201 or more", "10")
        ),
        numeric = TRUE
      ),
      tags$h3("Occurrence, the worst signal after the baseline"),
      docs_table(
        c("Signal", "Score"),
        list(
          c("Nothing flagged, and inside 1 to 6 \u00B0C", "1"),
          c("X-bar test 6", "2"),
          c("X-bar test 5 or test 8", "3"),
          c("X-bar test 4", "4"),
          c("X-bar test 2", "5"),
          c("X-bar test 7", "6"),
          c("X-bar test 3", "7"),
          c("Range chart test 1", "8"),
          c("X-bar test 1, still inside 1 to 6 \u00B0C", "9"),
          c("Any reading outside 1 to 6 \u00B0C", "10")
        ),
        numeric = TRUE
      ),
      tags$h3("Urgency, from the hours until the line crosses"),
      docs_table(
        c("Hours", "Score"),
        list(
          c("0 to 2", "10"), c("more than 2 to 4", "9"), c("more than 4 to 8", "8"),
          c("more than 8 to 12", "7"), c("more than 12 to 18", "6"),
          c("more than 18 to 24", "5"), c("more than 24 to 36", "4"),
          c("more than 36 to 48", "3"),           c("more than 48 to 72", "2"),
          c("more than 72, or no crossing", "1")
        ),
        numeric = TRUE
      )
    ),
    docs_section(
      "Data",
      "Three synthetic files, with a link and a row count for each",
      tags$p(paste("Every file is synthetic. Nothing here was measured on a real fridge, a real bag,",
                   "or a real generator. The safe storage range is 1 to 6 \u00B0C. The baseline is the",
                   "first 48 hours, 2026-10-01 00:00:00 through 2026-10-02 23:45:00, and the control",
                   "limits are frozen from it. Column meanings and the planted stories are in the",
                   "data codebook linked above.")),
      tags$div(
        class = "bbm-files",
        docs_file(
          "readings.csv",
          "4,032 rows",
          "Six fridges, one temperature every 15 minutes, 2026-10-01 through 2026-10-07. Columns: fridge_id, timestamp, temp_c, door_open, on_generator.",
          "https://github.com/rubberduckysmiles/Rwedoneyet/blob/main/data/readings.csv"
        ),
        docs_file(
          "inventory.csv",
          "40 rows",
          "Bags on the shelf, one row per fridge per blood type. Blood type is display only. It does not enter a limit, an index, or the risk priority number.",
          "https://github.com/rubberduckysmiles/Rwedoneyet/blob/main/data/inventory.csv"
        ),
        docs_file(
          "generator_log.csv",
          "30 rows",
          "One backup-generator transfer test per day, 2026-09-07 through 2026-10-06. A stopwatch from the cut in mains power until the generator carries the load.",
          "https://github.com/rubberduckysmiles/Rwedoneyet/blob/main/data/generator_log.csv"
        )
      ),
      tags$p(class = "mb-0",
             paste("Each scenario folder has its own readings.csv of 4,032 rows and a copy of the",
                   "other two files. A lab would record the same three things: a logger every 15",
                   "minutes, a bag count at shift change, and a stopwatch at the generator test."))
    ),
    docs_section(
      "Tests and Verification",
      "A known answer, a constant fridge, the demo file, and the commands that re-run them",
      tags$h3("Known answer"),
      tags$p(paste("Ten hours of four readings, and every hour mean is exactly 3.5 \u00B0C.",
                   "The rows live in the tests, not in a fourth CSV. Sum of squares is 1.98.",
                   "Mean variance is 0.066.")),
      docs_table(
        c("Quantity", "Value"),
        list(
          c("Sigma short", "0.2569046516"),
          c("Sigma overall", "0.2253202849"),
          c("X-bar lower limit", "3.1146430226"),
          c("X-bar upper limit", "3.8853569774"),
          c("Cpk", "3.2437456007"),
          c("Ppk", "3.6984390192"),
          c("Gap", "-0.4546934185"),
          c("Lag-1", "-0.2174115934")
        ),
        numeric = TRUE
      ),
      tags$h3("Two checks beside that answer"),
      tags$div(
        class = "bbm-checks",
        tags$div(
          class = "bbm-check",
          tags$span("Constant data"),
          tags$p("Every reading is 3.5 \u00B0C. Both sigmas are 0. Cpk and Ppk are missing. They are never infinity.")
        ),
        tags$div(
          class = "bbm-check",
          tags$span("A planted drift"),
          tags$p("Add 0, 0, 0, 0, 0, 0.2, 0.4, 0.6, 0.8, 1.0 \u00B0C to those ten hours. Sigma short stays 0.2569046516. Cpk becomes 2.8544961286, Ppk becomes 1.7091158726, and the gap becomes +1.1453802560.")
        )
      ),
      tags$h3("Demo file"),
      tags$div(
        class = "bbm-checks bbm-checks-4",
        tags$div(class = "bbm-check", tags$span("Fridges needing action"), tags$p("4")),
        tags$div(class = "bbm-check", tags$span("Blood units at risk"), tags$p("283")),
        tags$div(class = "bbm-check", tags$span("Average Ppk"), tags$p("5.719")),
        tags$div(class = "bbm-check", tags$span("Last transfer"), tags$p("48 seconds"))
      ),
      tags$h3("The two scenario sets"),
      docs_table(
        c("Set", "Needing action", "Bags at risk", "Average Ppk"),
        list(
          c("scenario_one_bad", "2 of 6", "275", "5.42"),
          c("scenario_one_good", "2 of 6", "67", "5.73")
        )
      ),
      tags$p(paste("On the good set, F02 has no reading outside 1 to 6 \u00B0C and a Cpk of 0.537.",
                   "F06 is the fridge the range check catches: 16 readings above 6 \u00B0C and a Cpk of 0.598.")),
      tags$h3("What the badge rule was checked against"),
      tags$ul(
        tags$li("If one flag anywhere were enough, 92.0% of a simulated healthy fleet would be red or amber."),
        tags$li("With two flags inside the last day, that share is 15.5%."),
        tags$li("A fridge that really drifts out of range is still red on 100% of those draws.")
      ),
      tags$h3("Run it again"),
      tags$ul(
        class = "mb-0",
        tags$li("Rscript app/workflow.R prints WORKFLOW OK when the known answer still matches."),
        tags$li("Rscript demo/show_numbers.R prints DEMO OK, including the four demo numbers above."),
        tags$li("Rscript -e 'testthat::test_dir(\"tests\")' runs the full suite.")
      )
    ),
    docs_section(
      "Assumptions and Limitations",
      "What the numbers assume, and what they leave out",
      docs_table(
        c("Topic", "What the tool assumes", "What that leaves out"),
        list(
          list(
            "Normal, independent hours",
            "Sample variances divide by n \u2212 1. The limits are 3 sigma on either side of the center.",
            "Lag-1 autocorrelation is printed. It is not used to widen the limits."
          ),
          list(
            "Frozen baseline",
            "Limits come from the first 48 hours and then stay put. Fewer than 25 subgroups means no limits.",
            "A later shift in the process does not move the lines."
          ),
          list(
            "Standard deviation chart",
            "It is drawn from c4, B5, and B6.",
            "Its flags do not enter the badge, the risk priority number, the bag count, or the violations table."
          ),
          list(
            "Two clocks",
            "The badge and the bags at risk use the last 24 hours.",
            "The capability sentence and the occurrence score use the whole chart after the baseline, so a failure that is already over can still outrank a live one."
          ),
          list(
            "Straight-line forecast",
            "Hours to a spec limit is one line through the later hourly means. A crossing within 12 hours can turn the badge amber.",
            "It does not predict a door spike or a generator failure, and the fridge card does not print it."
          ),
          list(
            "10 second line",
            "A threshold the team chose for this site's generator test.",
            "It is not a control limit and not a spec limit."
          ),
          list(
            "Blood type",
            "Shown so a manager can see which bags are in the fridge.",
            "It does not enter a limit, an index, or the risk priority number."
          ),
          list(
            "Synthetic files",
            "Invented to show one behaviour per fridge.",
            "They are not a real blood bank's stock."
          )
        )
      )
    )
  )
}

# ---- UI ------------------------------------------------------------------------------------------

ui <- bslib::page_navbar(
  title = "Bank of Bloody Mary",
  id = "main_nav",
  theme = theme,
  fillable = FALSE,
  # The name sits on a dark red bar. theme = "dark" makes the title and the tabs
  # light enough to read on #B3202A, in either color mode.
  navbar_options = bslib::navbar_options(bg = "#B3202A", theme = "dark"),

  bslib::nav_panel(
    "Overview",
    tags$style(HTML("
      .bbm-label { font-size: 0.68rem; letter-spacing: 0.14em; text-transform: uppercase; color: var(--bs-secondary-color); }
      .bbm-number { font-size: 2.6rem; font-weight: 500; letter-spacing: -0.03em; line-height: 1.05; font-variant-numeric: tabular-nums; }
      .bbm-number-quiet { font-size: 1.45rem; font-weight: 500; line-height: 1.15; font-variant-numeric: tabular-nums; }
      .bbm-over { color: #D64045; }
      .bbm-ok { color: #2E9E6B; }
      .bbm-figure { font-size: 1rem; font-weight: 500; font-variant-numeric: tabular-nums; }
      .bbm-fridge.card { border-left: 7px solid var(--bbm-edge); }
      .bbm-status { background: var(--bs-body-bg); border: 3px solid var(--bs-border-color); }
    ")),
    bslib::layout_columns(
      fill = FALSE,
      class = "mb-3",
      col_widths = bslib::breakpoints(sm = c(12, 12), lg = c(8, 4)),
      uiOutput("status_card"),
      uiOutput("overview_dataset_picker")
    ),
    uiOutput("overview_boxes"),
    uiOutput("overview_notes"),
    uiOutput("fridge_cards"),
    tags$p(class = "text-muted small mt-2 mb-0", "Control limits are locked from each fridge's first 48 hours.")
  ),

  bslib::nav_panel(
    "Fridge and Generator Detail",
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        selectInput("fridge", "Show", choices = character(0)),
        tags$p(class = "text-muted small",
               paste("Pick a fridge, or the site's backup generator. The generator is one",
                     "log for the whole plant, not a seventh fridge.")),
        shiny::conditionalPanel(
          condition = "input.fridge != 'generator'",
          dateRangeInput("dates", "Date range"),
          checkboxInput("zone_lines", "Show zone lines (1 and 2 standard errors)", value = TRUE),
          tags$p(class = "text-muted small mb-0",
                 paste("Zone lines mark 1 and 2 standard errors out from the center line:",
                       "shading for where the points usually fall. They are not control limits."))
        )
      ),
      shiny::conditionalPanel(
        condition = "input.fridge != 'generator'",
        uiOutput("detail_alert"),
        bslib::card(plotlyOutput("xbar_chart", height = "380px"), full_screen = TRUE),
        bslib::card(plotlyOutput("range_chart", height = "280px"), full_screen = TRUE),
        bslib::card(plotlyOutput("sd_chart", height = "280px"), full_screen = TRUE),
        bslib::card(
          bslib::card_header("Blood types in this fridge"),
          uiOutput("bloodtype_note"),
          plotlyOutput("bloodtype_chart", height = "260px"),
          full_screen = TRUE
        ),
        bslib::card(bslib::card_header("Violations"), DT::DTOutput("violations_table"))
      ),
      shiny::conditionalPanel(
        condition = "input.fridge == 'generator'",
        uiOutput("generator_note"),
        bslib::card(plotlyOutput("gen_ind_chart", height = "320px"), full_screen = TRUE),
        bslib::card(plotlyOutput("gen_mr_chart", height = "260px"), full_screen = TRUE)
      )
    )
  ),

  bslib::nav_panel(
    "Capability",
    tags$style(HTML("
      .bbm-cap-frame { position: relative; }
      .bbm-cap-picker { position: absolute; z-index: 2; top: 0.45rem; right: 0.75rem; width: 12.5rem; }
      .bbm-cap-picker .shiny-input-container { margin-bottom: 0; }
      .bbm-cap-picker label { color: #FFFFFF; font-size: 0.72rem; margin-bottom: 0.1rem; }
      .bbm-cap.card { border-left: 7px solid var(--bbm-edge); }
      .bbm-cap .card-header {
        background-color: #B3202A; color: #FFFFFF;
        min-height: 4.6rem; display: flex; align-items: center;
        padding-right: 14.5rem;
      }
      .bbm-cap .card-header h4 { color: #FFFFFF; }
      @media (max-width: 640px) {
        .bbm-cap-frame { display: flex; flex-direction: column; }
        .bbm-cap-picker { position: static; width: auto; order: -1; margin-bottom: 0.75rem; }
        .bbm-cap-picker label { color: inherit; }
        .bbm-cap .card-header { padding-right: 1rem; min-height: 0; }
      }
    ")),
    tags$div(
      class = "bbm-cap-frame mb-3",
      uiOutput("capability_verdict"),
      tags$div(class = "bbm-cap-picker", selectInput("cap_fridge", "Fridge", choices = character(0)))
    ),
    uiOutput("capability_notes"),
    bslib::layout_columns(
      col_widths = bslib::breakpoints(sm = 12, lg = 6),
      bslib::card(
        bslib::card_header("Baseline readings against the spec"),
        tags$p(class = "text-muted small mb-1",
               "The band between the lines is 1\u20136 \u00B0C."),
        tags$details(
          class = "small text-muted mb-2",
          tags$summary("How to read this chart"),
          tags$p(class = "mt-2 mb-0",
                 paste("Bars are the baseline readings. The lines at 1 \u00B0C and 6 \u00B0C are",
                       "the spec limits for stored red cells, with 3.5 \u00B0C as the target between",
                       "them. Control limits come from the process itself and are drawn on the",
                       "X-bar chart on the Fridge and Generator Detail page."))
        ),
        plotlyOutput("hist_chart", height = "320px")
      ),
      bslib::card(
        bslib::card_header("Rolling 24-hour Ppk"),
        tags$p(class = "text-muted small mb-1", "The dashed line is 1.0."),
        tags$details(
          class = "small text-muted mb-2",
          tags$summary("How to read this chart"),
          tags$p(class = "mt-2 mb-0",
                 paste("Ppk recomputed over the trailing 96 readings - 24 hours at 15-minute",
                       "intervals - at each point, using only that window's own spread. It needs",
                       "at least 24 hours of data. A falling line means the fridge is getting",
                       "worse now, whatever the baseline says."))
        ),
        plotlyOutput("rolling_chart", height = "320px")
      )
    ),
    uiOutput("capability_generator")
  ),

  bslib::nav_panel(
    "Data",
    bslib::layout_columns(
      col_widths = bslib::breakpoints(sm = 12, md = 4),
      fileInput("up_readings", "Readings (fridge_id, timestamp, temp_c, door_open, on_generator)", accept = ".csv"),
      fileInput("up_inventory", "Inventory (fridge_id, blood_type, blood_units)", accept = ".csv"),
      fileInput("up_generator", "Backup generator log (date, transfer_time_sec)", accept = ".csv")
    ),
    selectInput("dataset", "Dataset", choices = DATASET_CHOICES),
    actionButton("load_demo", "Load dataset", class = "btn-primary mb-3"),
    tags$p(class = "text-muted small", DATASET_HELP),
    uiOutput("data_status"),
    bslib::navset_card_tab(
      title = "Preview",
      bslib::nav_panel("Readings", DT::DTOutput("preview_readings")),
      bslib::nav_panel("Inventory", DT::DTOutput("preview_inventory")),
      bslib::nav_panel("Backup generator log", DT::DTOutput("preview_generator"))
    )
  ),

  bslib::nav_panel("Docs", docs_page()),

  bslib::nav_spacer(),
  bslib::nav_item(bslib::input_dark_mode(id = "color_mode"))
)

# ---- Server --------------------------------------------------------------------------------------

server <- function(input, output, session) {
  demo <- load_demo_data(data_dir)
  rv <- reactiveValues(
    readings = demo$readings, inventory = demo$inventory, backup_generator = demo$generator,
    from_readings = if (is.null(demo$readings)) "none" else "General demo (planted failures)",
    from_inventory = if (is.null(demo$inventory)) "none" else "General demo (planted failures)",
    from_backup_generator = if (is.null(demo$generator)) "none" else "General demo (planted failures)",
    # Which dataset is loaded, and whether an upload replaced it. The Overview picker and
    # the Data page picker both read and write dataset_id.
    dataset_id = "general",
    manual_upload = FALSE
  )

  dark <- reactive(identical(input$color_mode, "dark"))

  analyses <- reactive(analyze_all(rv$readings, rv$inventory))
  summary_numbers <- reactive(overview_summary(analyses(), rv$backup_generator))
  gen <- reactive(generator_analysis(rv$backup_generator))

  # ---- Data page
  try_upload <- function(file, prepare, slot, label) {
    tryCatch({
      data <- prepare(utils::read.csv(file$datapath, stringsAsFactors = FALSE))
      rv[[slot]] <- data
      rv[[paste0("from_", slot)]] <- file$name
      # An upload replaces the dataset source, so the pickers no longer describe what is
      # on screen. Flag it rather than let a picker claim a dataset that is not loaded.
      rv$manual_upload <- TRUE
    }, error = function(e) {
      showNotification(paste0("Could not load ", label, ": ", conditionMessage(e)), type = "error", duration = 12)
    })
  }
  observeEvent(input$up_readings, try_upload(input$up_readings, prepare_readings, "readings", "readings"))
  observeEvent(input$up_inventory, try_upload(input$up_inventory, prepare_inventory, "inventory", "inventory"))
  observeEvent(input$up_generator, try_upload(input$up_generator, prepare_generator, "backup_generator", "backup generator log"))

  # One loader, shared by the Data page's button and the Overview's dropdown, so the two
  # cannot load a dataset differently. Returns the dataset id on success, NULL on failure.
  load_dataset <- function(dataset_id) {
    if (is.null(dataset_id) || !dataset_id %in% names(DATASETS)) dataset_id <- "general"
    folder <- file.path(data_dir, DATASETS[[dataset_id]])
    display_name <- DATASET_LABELS[[dataset_id]]
    d <- load_demo_data(folder)
    if (is.null(d$readings)) {
      showNotification(paste0("Demo data not found in ", folder, ". Expected readings.csv, inventory.csv and generator_log.csv."),
                       type = "error")
      return(NULL)
    }
    rv$readings <- d$readings
    rv$inventory <- d$inventory
    rv$backup_generator <- d$generator
    rv$from_readings <- rv$from_inventory <- rv$from_backup_generator <- display_name
    rv$dataset_id <- dataset_id
    # An uploaded file is no longer the source, so drop the manual-upload flag.
    rv$manual_upload <- FALSE
    dataset_id
  }

  # Which dataset is on screen. Tracked in rv rather than read from an input, because the
  # Data page picker and the Overview picker are two controls for one piece of state and
  # either can change it.
  overview_dataset_id <- reactive({
    if (is.null(rv$dataset_id)) "general" else rv$dataset_id
  })

  observeEvent(input$load_demo, {
    loaded <- load_dataset(input$dataset)
    if (is.null(loaded)) return()
    showNotification(paste0("Loaded ", DATASET_LABELS[[loaded]], "."), type = "message")
  })

  # The Overview dropdown applies the moment a value is chosen. This must NOT use
  # ignoreInit: the first pick a manager makes arrives as the observer's first change, and
  # ignoreInit would swallow exactly that one. A NULL (nothing chosen yet) is skipped
  # instead, and re-picking the dataset already loaded is a no-op.
  observeEvent(input$overview_dataset, {
    if (is.null(input$overview_dataset)) return()
    if (identical(input$overview_dataset, rv$dataset_id)) return()
    loaded <- load_dataset(input$overview_dataset)
    if (is.null(loaded)) return()
    # Keep the Data page picker showing the same dataset.
    updateSelectInput(session, "dataset", selected = loaded)
    showNotification(paste0("Loaded ", DATASET_LABELS[[loaded]], "."), type = "message")
  })

  output$data_status <- renderUI({
    tags$p(class = "text-muted",
           sprintf("Readings: %s. Inventory: %s. Backup generator log: %s.", rv$from_readings, rv$from_inventory, rv$from_backup_generator))
  })

  preview_table <- function(df) {
    if (is.null(df)) return(DT::datatable(data.frame(note = "Nothing loaded."), rownames = FALSE, options = list(dom = "t")))
    show <- df
    if ("timestamp" %in% names(show)) show$timestamp <- time_text(show$timestamp)
    DT::datatable(show, rownames = FALSE, options = list(pageLength = 10, dom = "tip"))
  }
  output$preview_readings <- DT::renderDT(preview_table(rv$readings))
  output$preview_inventory <- DT::renderDT(preview_table(rv$inventory))
  output$preview_generator <- DT::renderDT(preview_table(rv$backup_generator))

  # ---- Fridge pickers
  observeEvent(analyses(), {
    ids <- sort(names(analyses()))
    fridge_choices <- stats::setNames(ids, fridge_label(ids))
    # The generator is a site log. It is a choice on this page only, never a fridge
    # on the Capability picker.
    detail_choices <- c(fridge_choices, stats::setNames(GENERATOR_CHOICE, "Backup generator"))
    keep <- if (isTRUE(input$fridge %in% c(ids, GENERATOR_CHOICE))) input$fridge else ids[1]
    updateSelectInput(session, "fridge", choices = detail_choices, selected = keep)
    updateSelectInput(session, "cap_fridge", choices = fridge_choices, selected = if (isTRUE(input$cap_fridge %in% ids)) input$cap_fridge else ids[1])
  }, ignoreNULL = FALSE)

  detail <- reactive({
    req(input$fridge)
    a <- analyses()[[input$fridge]]
    req(a)
    a
  })

  observeEvent(list(input$fridge, analyses()), {
    if (!isTruthy(input$fridge)) return()
    a <- analyses()[[input$fridge]]
    if (is.null(a) || nrow(a$subgroups) == 0) return()
    first <- as.Date(min(a$subgroups$time))
    last <- as.Date(max(a$subgroups$time))
    updateDateRangeInput(session, "dates", start = first, end = last, min = first, max = last)
  })

  # ---- Overview
  output$status_card <- renderUI({
    if (length(analyses()) == 0) return(NULL)
    tags$div(
      class = "bbm-status rounded-3 p-3 px-4 h-100 mb-0",
      tags$p(class = "mb-3 fw-semibold", style = "font-size: 1.2rem;",
             tags$span(class = "me-2", "Status:"),
             shift_status(analyses())),
      tags$div(
        tags$span(class = "badge rounded-pill me-2", style = "background-color:#2E9E6B;color:#FFFFFF;", "Leave it"),
        tags$span(class = "badge rounded-pill me-2", style = "background-color:#E8A33D;color:#212529;", "Watch this shift"),
        tags$span(class = "badge rounded-pill", style = "background-color:#D64045;color:#FFFFFF;", "Act this shift")
      )
    )
  })

  output$overview_boxes <- renderUI({
    if (length(analyses()) == 0) {
      return(tags$div(class = "alert alert-info", "No readings loaded. Open the Data page and press Load dataset."))
    }
    s <- summary_numbers()
    over <- isTRUE(s$last_transfer > 10)
    # Zero means nothing to chase, so it reads green; anything else reads red. The same rule
    # for both counts. Average Ppk is judged against 1, the fit its own note describes; NA
    # means no fridge has usable limits yet, which is neither good nor bad news, so it keeps
    # the default colour rather than claiming either.
    count_class <- function(n) if (isTRUE(n == 0)) "bbm-ok" else "bbm-over"
    ppk_class <- if (is.na(s$average_ppk)) NULL else if (s$average_ppk >= 1) "bbm-ok" else "bbm-over"
    transfer <- if (is.na(s$last_transfer)) "\u2014" else paste0(fmt_num(s$last_transfer, 1), " s")
    tagList(
      bslib::layout_columns(
        fill = FALSE,
        col_widths = bslib::breakpoints(sm = 12, md = 6),
        stat_box("Fridges needing action", s$needing_action, sprintf("of %d fridges, red or amber", length(analyses())),
                 value_class = count_class(s$needing_action)),
        stat_box("Blood units at risk", format(s$units_at_risk, big.mark = ","), "out of range now, or flagged in the last 24 h",
                 value_class = count_class(s$units_at_risk))
      ),
      bslib::layout_columns(
        fill = FALSE, class = "mt-3",
        col_widths = bslib::breakpoints(sm = 12, md = 6),
        stat_box("Average Ppk", fmt_num(s$average_ppk, 2), "Mean of each fridge's Ppk, in sigmas. Above 1.0, the baseline fits inside 1\u20136 \u00B0C.",
                 quiet = TRUE, value_class = ppk_class),
        stat_box("Last backup test", transfer,
                 if (is.na(s$last_transfer)) "No backup test loaded." else "Seconds to backup power. The 10 s line is a threshold the manager sets for their own site.",
                 quiet = TRUE, value_class = if (over) "bbm-over" else NULL)
      )
    )
  })

  # Dataset picker on the Overview, on the same row as the status sentence. The dropdown
  # applies immediately and stays in step with the Data page picker. The card is the
  # dropdown, the upload warning, and one line. The longer description stays on the Data page.
  output$overview_dataset_picker <- renderUI({
    bslib::card(
      fill = FALSE,
      class = "h-100",
      bslib::card_header("Dataset"),
      selectInput("overview_dataset", NULL, choices = DATASET_CHOICES,
                  selected = overview_dataset_id()),
      if (isTRUE(rv$manual_upload)) {
        tags$p(class = "small mb-2", style = "color:#D64045;",
               paste("Uploaded files are in use, so the numbers above are not this dataset.",
                     "Pick a dataset here to replace them."))
      },
      tags$p(class = "text-muted small mb-0", DATASET_HELP_SHORT)
    )
  })

  # The column meanings, stated once and closed. Open it when someone asks what a
  # number means. The phrases stay in the page so a test can still find them.
  output$overview_notes <- renderUI({
    if (length(analyses()) == 0) return(NULL)
    bslib::card(
      fill = FALSE,
      class = "mb-3",
    tags$details(
      class = "small text-muted",
      tags$summary("How to read the fridge cards"),
      tags$p(class = "mt-2 mb-2",
             paste("Blood units are the bags stored. Ppk is the room between this",
                   "fridge's readings and the nearer of 1 °C or 6 °C, counted in",
                   "sigmas. Mean and Std dev are the fridge's baseline average",
                   "temperature and its typical hour-to-hour spread, from the",
                   "first 48 hours.")),
      tags$p(class = "mb-2",
             paste("Risk priority number is severity × occurrence × urgency, each scored 1 to 10.",
                   "Severity is the bag count banded 1 to 10, occurrence is the worst",
                   "special-cause pattern that fired, and urgency is how soon the forecast",
                   "reaches 1 °C or 6 °C. Higher acts first.")),
      tags$p(class = "mb-0",
             paste("The sentence under each card is that fridge's own newest special-cause",
                   "meaning, from the last 24 hours; \"No special-cause flag.\" means its last",
                   "day was clean."))
    )
    )
  })

  output$fridge_cards <- renderUI({
    list_a <- analyses()
    if (length(list_a) == 0) return(NULL)
    ids <- names(list_a)
    rpns <- vapply(list_a, function(a) a$rpn, numeric(1))
    rank_order <- order(-rpns, ids)
    rank_of <- integer(length(ids))
    rank_of[rank_order] <- seq_along(ids)
    names(rank_of) <- ids
    list_a <- list_a[order(ids)]
    cards <- lapply(list_a, function(a) {
      htmltools::tagAppendAttributes(
      bslib::card(
        fill = FALSE,
        class = "bbm-fridge",
        bslib::card_header(
          class = "d-flex justify-content-between align-items-center",
          tags$strong(a$fridge_id), status_badge(a)
        ),
        tags$div(
          class = "row g-2 align-items-center mb-2",
          tags$div(
            class = "col-7",
            plotlyOutput(paste0("spark_", safe_id(a$fridge_id)), height = "180px")
          ),
          tags$div(
            class = "col-5 d-flex flex-column justify-content-center gap-1 small",
            card_stat("Blood units", a$blood_units),
            card_stat("Ppk", fmt_num(a$ppk, 2)),
            card_stat("RPN", sprintf("%d (%d \u00d7 %d \u00d7 %d)", a$rpn, a$severity, a$occurrence, a$urgency)),
            card_stat("Mean (\u00B0C)", fmt_num(if (isTRUE(a$has_limits)) a$baseline$center else NA_real_, 2)),
            card_stat("Std dev (\u00B0C)", fmt_num(if (isTRUE(a$has_limits)) a$baseline$sigma_short else NA_real_, 2))
          )
        ),
        tags$p(class = "mb-0 small", a$flag_sentence)
      ),
      style = sprintf("--bbm-edge:%s;", a$status_color)
      )
    })
    do.call(bslib::layout_columns,
            c(list(fill = FALSE, col_widths = bslib::breakpoints(sm = 12, md = 6, xl = 4)), unname(cards)))
  })

  observe({
    for (a_id in names(analyses())) {
      local({
        id <- a_id
        output[[paste0("spark_", safe_id(id))]] <- renderPlotly(sparkline_plot(analyses()[[id]], dark()))
      })
    }
  })

  # ---- Fridge Detail
  # Banner at the top of Fridge Detail: which special-cause rules fired (monitored only),
  # with a plain-language description of each. Green "stable" when none fired.
  RULE_NAMES <- c(
    "1" = "Rule 1: one point beyond 3 sigma",
    "2" = "Rule 2: nine points in a row on one side of the center",
    "3" = "Rule 3: six points in a row steadily rising or falling",
    "4" = "Rule 4: fourteen points in a row alternating up and down",
    "5" = "Rule 5: two of three points beyond 2 sigma on the same side",
    "6" = "Rule 6: four of five points beyond 1 sigma on the same side",
    "7" = "Rule 7: fifteen points in a row inside 1 sigma",
    "8" = "Rule 8: eight points in a row beyond 1 sigma"
  )

  output$detail_alert <- renderUI({
    a <- detail()
    req(a)
    monitored <- a$violations[a$violations$monitored, , drop = FALSE]
    if (nrow(monitored) == 0) {
      return(tags$div(class = "alert alert-success mb-3",
                      tags$strong("Stable. "),
                      "No special-cause rule triggered on this fridge."))
    }
    uniq_tests <- sort(unique(monitored$test))
    rules_list <- lapply(uniq_tests, function(t) {
      meaning <- monitored$meaning[monitored$test == t][1]
      charts <- unique(monitored$chart[monitored$test == t])
      rule_name <- RULE_NAMES[as.character(t)]
      if (is.na(rule_name)) rule_name <- sprintf("Test %d", t)
      tags$div(class = "mb-2",
        tags$strong(sprintf("%s (%s): ", rule_name, paste(charts, collapse = ", "))),
        tags$span(meaning)
      )
    })
    alert_class <- if (a$status == "red") "alert alert-danger" else if (a$status == "amber") "alert alert-warning" else "alert alert-info"
    tags$div(class = paste(alert_class, "mb-3"),
      tags$h5(class = "mb-2", "Special-cause rules triggered"),
      tagList(rules_list)
    )
  })

  # Blood types for the selected fridge, split into at-risk and within-spec bags.
  bloodtype_data <- reactive({
    a <- detail()
    bloodtype_table(rv$inventory, a$fridge_id, a$units_at_risk)
  })

  output$bloodtype_note <- renderUI({
    a <- detail()
    bt <- bloodtype_data()
    if (nrow(bt) == 0) {
      return(tags$p(class = "text-muted small mb-0",
                    "No blood types on file for this fridge. The inventory file carries one row per fridge per type (fridge_id, blood_type, blood_units)."))
    }
    total <- sum(bt$blood_units)
    at_risk <- sum(bt$units_at_risk)
    risk_text <- if (at_risk > 0) {
      sprintf("%d of %d bags are at risk, because %s is %s.", round(at_risk), round(total),
              fridge_label(a$fridge_id), sub("^[a-z]+: ", "", a$status_label))
    } else {
      sprintf("All %d bags are inside the spec right now.", round(total))
    }
    tags$p(class = "text-muted small mb-0", risk_text)
  })

  output$bloodtype_chart <- renderPlotly({
    a <- detail()
    bloodtype_plot(bloodtype_data(), dark())
  })

  output$xbar_chart <- renderPlotly({
    a <- detail()
    xbar_plot(a, visible_rows(a, input$dates), input$zone_lines, dark())
  })
  output$range_chart <- renderPlotly({
    a <- detail()
    range_plot(a, visible_rows(a, input$dates), dark())
  })
  output$sd_chart <- renderPlotly({
    a <- detail()
    sd_plot(a, visible_rows(a, input$dates), dark())
  })
  output$violations_table <- DT::renderDT({
    a <- detail()
    v <- a$violations
    v <- v[as.Date(v$time) >= (input$dates[1] %||% as.Date("1970-01-01")) &
             as.Date(v$time) <= (input$dates[2] %||% as.Date("2999-01-01")), , drop = FALSE]
    shown <- data.frame(Time = time_text(v$time), Chart = v$chart, Test = v$test, Meaning = v$meaning,
                        stringsAsFactors = FALSE)
    DT::datatable(shown, rownames = FALSE, options = list(pageLength = 8, dom = "tip"),
                  caption = if (nrow(shown) == 0) "No violations in this date range." else NULL)
  })

  # ---- Capability
  cap <- reactive({
    req(input$cap_fridge)
    a <- analyses()[[input$cap_fridge]]
    req(a)
    a
  })

  # capability_top is the same three pieces, kept together so a test can read one
  # output. The page itself shows the verdict, the notes, the charts, then the generator.
  output$capability_verdict <- renderUI(capability_verdict_card(cap()))
  output$capability_notes <- renderUI(capability_notes_card(cap()))
  output$capability_generator <- renderUI(capability_generator_card(generator_stats(gen())))
  output$capability_top <- renderUI({
    tagList(
      capability_verdict_card(cap()),
      capability_notes_card(cap()),
      capability_generator_card(generator_stats(gen()))
    )
  })
  output$hist_chart <- renderPlotly(histogram_plot(cap(), dark()))
  output$rolling_chart <- renderPlotly(rolling_plot(cap(), dark()))

  # ---- Generator
  output$generator_note <- renderUI({
    g <- gen()
    if (is.null(g)) {
      return(tags$div(class = "alert alert-warning", "No backup generator log loaded. Add one on the Data page. The Overview box shows a dash until then."))
    }
    msg <- g$limits$message
    tags$p(class = "text-muted", if (nzchar(msg)) msg else
      sprintf("%d transfer tests. The solid dark line marks the 10 s threshold the team chose for their own site.", g$n))
  })
  gen_plots <- reactive({
    g <- gen()
    req(g)
    generator_plots(g, dark())
  })
  output$gen_ind_chart <- renderPlotly({
    validate(need(!is.null(gen()), "No backup generator log loaded."))
    gen_plots()$individuals
  })
  output$gen_mr_chart <- renderPlotly({
    validate(need(!is.null(gen()), "No backup generator log loaded."))
    gen_plots()$moving_range
  })
}

shinyApp(ui, server)
