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

theme <- bslib::bs_theme(preset = "shiny", primary = "#B3202A", font = bslib::font_google("Inter"))

# One color per test number for flagged points. Red, amber and green are kept for status only.
TEST_COLORS <- c("#7B2D8E", "#0072B2", "#56B4E9", "#CC79A7", "#8C564B", "#17BECF", "#555555", "#B8860B")
CAPABLE_SENTENCES <- c("capable and stable", "inside the spec width, but not stable", "not capable")

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
themed <- function(p, dark) {
  fg <- if (isTRUE(dark)) "#E6E6E6" else "#212529"
  grid <- if (isTRUE(dark)) "rgba(255,255,255,0.12)" else "rgba(0,0,0,0.10)"
  p %>%
    layout(
      paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
      font = list(color = fg),
      xaxis = list(gridcolor = grid, zerolinecolor = grid),
      yaxis = list(gridcolor = grid, zerolinecolor = grid),
      legend = list(orientation = "h", y = -0.2)
    ) %>%
    config(displayModeBar = FALSE)
}

empty_plot <- function(text, dark = FALSE) {
  plot_ly() %>%
    layout(annotations = list(text = text, showarrow = FALSE, x = 0.5, y = 0.5, xref = "paper", yref = "paper"),
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

stat_box <- function(label, value, note, quiet = FALSE, value_class = NULL) {
  tags$div(
    class = "h-100 p-3 border rounded-3 bg-body",
    tags$div(class = "bbm-label", label),
    tags$div(class = paste(if (quiet) "bbm-number-quiet" else "bbm-number", value_class), value),
    tags$div(class = "text-muted small mt-2", note)
  )
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
    layout(shapes = shapes, yaxis = list(title = "Hourly mean (\u00B0C)"), xaxis = list(title = ""),
           title = list(text = "X-bar chart. Limits are the baseline mean \u00b1 3 standard errors. Gray marks the first 48 hours.", font = list(size = 14))) %>%
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
           yaxis = list(title = "Hourly range (\u00B0C)"), xaxis = list(title = ""),
           title = list(text = "Range chart", font = list(size = 14))) %>%
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
           yaxis = list(title = "Hourly standard deviation (\u00B0C)", autosize = TRUE),
           xaxis = list(title = ""),
           title = list(text = "Standard deviation chart (dispersion; limits frozen)", font = list(size = 14))) %>%
    themed(dark)
}

histogram_plot <- function(a, dark) {
  if (!a$has_limits) return(empty_plot(a$baseline$message, dark))
  shapes <- list(vline(SPEC_LOW, "#444444"), vline(TARGET_TEMP, "#6C757D"), vline(SPEC_HIGH, "#444444"))
  notes <- list(
    list(x = SPEC_LOW, text = "1 \u00B0C (lower spec)"),
    list(x = TARGET_TEMP, text = "3.5 \u00B0C (target)"),
    list(x = SPEC_HIGH, text = "6 \u00B0C (upper spec)")
  )
  notes <- lapply(notes, function(n) c(n, list(y = 1, yref = "paper", xref = "x", showarrow = FALSE, yanchor = "bottom")))
  plot_ly(x = a$base_readings, type = "histogram", nbinsx = 30, marker = list(color = "#6C757D"),
          hovertemplate = "%{x} C: %{y} readings<extra></extra>") %>%
    layout(shapes = shapes, annotations = notes,
           xaxis = list(title = "Baseline temperature (\u00B0C)", range = c(0.5, 6.5)),
           yaxis = list(title = "Readings"), showlegend = FALSE,
           margin = list(t = 40)) %>%
    themed(dark)
}

rolling_plot <- function(a, dark) {
  if (length(a$rolling_ppk) == 0) return(empty_plot("need at least 24 hours of readings", dark))
  plot_ly(x = a$rolling_time, y = a$rolling_ppk, type = "scatter", mode = "lines",
          line = list(color = "#444444", width = 2),
          text = sprintf("%s<br>Ppk %s", time_text(a$rolling_time), formatC(a$rolling_ppk, format = "f", digits = 2)),
          hoverinfo = "text") %>%
    layout(yaxis = list(title = "Rolling 24-hour Ppk"), xaxis = list(title = ""), showlegend = FALSE) %>%
    themed(dark)
}

# Bags by blood type for one fridge. Display only: the counts come from the inventory
# sheet and the at-risk split from bloodtype_table(), which divides by the fridge's own
# total. The badge color marks the at-risk bags, so the chart never invents a new color
# meaning. Sorted commonest first, which bloodtype_table() already does.
bloodtype_plot <- function(bt, status_color, dark) {
  if (nrow(bt) == 0) {
    return(empty_plot("No inventory rows for this fridge.<br>Add blood_type to the inventory file.", dark))
  }
  at_risk <- bt$units_at_risk
  safe <- bt$blood_units - at_risk
  plot_ly() %>%
    add_bars(x = ~safe, y = ~bt$blood_type, orientation = "h", name = "Within spec",
             marker = list(color = "#9AA0A6"),
             text = ~sprintf("%d bags", round(safe)), textposition = "inside",
             hovertemplate = "%{y}: %{x} bags within spec<extra></extra>") %>%
    add_bars(x = ~at_risk, y = ~bt$blood_type, orientation = "h", name = "At risk",
             marker = list(color = status_color),
             text = ~ifelse(at_risk > 0, sprintf("%d at risk", round(at_risk)), ""),
             textposition = "inside",
             hovertemplate = "%{y}: %{x} bags at risk<extra></extra>") %>%
    layout(barmode = "stack",
           xaxis = list(title = "Red-cell bags", gridcolor = if (isTRUE(dark)) "rgba(255,255,255,0.12)" else "rgba(0,0,0,0.10)"),
           yaxis = list(title = "", categoryorder = "total ascending"),
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
                                   xanchor = "right", yanchor = "bottom")),
           xaxis = list(title = "Test number (in date order)"), yaxis = list(title = "Transfer time (s)"),
           title = list(text = "Individuals chart", font = list(size = 14))) %>%
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
    layout(shapes = mr_shapes, xaxis = list(title = "Test number (in date order)"),
           yaxis = list(title = "Moving range (s)"), showlegend = FALSE,
           title = list(text = "Moving-range chart", font = list(size = 14))) %>%
    themed(dark)
  list(individuals = ind, moving_range = mr)
}

# ---- UI ------------------------------------------------------------------------------------------

ui <- bslib::page_navbar(
  title = "Bank of Bloody Mary",
  id = "main_nav",
  theme = theme,
  fillable = FALSE,

  bslib::nav_panel(
    "Overview",
    tags$style(HTML("
      .bbm-label { font-size: 0.68rem; letter-spacing: 0.14em; text-transform: uppercase; color: var(--bs-secondary-color); }
      .bbm-number { font-size: 2.6rem; font-weight: 500; letter-spacing: -0.03em; line-height: 1.05; font-variant-numeric: tabular-nums; }
      .bbm-number-quiet { font-size: 1.45rem; font-weight: 500; line-height: 1.15; font-variant-numeric: tabular-nums; }
      .bbm-over { color: #D64045; }
      .bbm-figure { font-size: 1rem; font-weight: 500; font-variant-numeric: tabular-nums; }
      .bbm-fridge .card { border-left: 3px solid var(--bbm-edge); }
      .bbm-status { background: var(--bs-body-bg); border: 3px solid var(--bs-border-color); }
    ")),
    uiOutput("status_card"),
    uiOutput("overview_boxes"),
    uiOutput("fridge_cards"),
    tags$p(class = "text-muted small mt-2 mb-0", "Control limits are locked from each fridge's first 48 hours. Priority = how many bags \u00d7 how bad the signal \u00d7 how soon, each scored from 1 to 10.")
  ),

  bslib::nav_panel(
    "Fridge Detail",
    uiOutput("detail_alert"),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        selectInput("fridge", "Fridge", choices = character(0)),
        dateRangeInput("dates", "Date range"),
        checkboxInput("zone_lines", "Show zone lines (1 and 2 standard errors)", value = TRUE),
        tags$p(class = "text-muted small mb-0",
               paste("Zone lines mark 1 and 2 standard errors out from the center line:",
                     "shading for where the points usually fall. They are not control limits."))
      ),
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
    )
  ),

  bslib::nav_panel(
    "Capability",
    selectInput("cap_fridge", "Fridge", choices = character(0)),
    uiOutput("capability_top"),
    bslib::layout_columns(
      col_widths = bslib::breakpoints(sm = 12, lg = 6),
      bslib::card(
        bslib::card_header("Baseline readings against the spec"),
        tags$p(class = "text-muted small mb-0",
               paste("Bars are the baseline readings. The lines at 1 \u00B0C and 6 \u00B0C are",
                     "the spec limits for stored red cells, with 3.5 \u00B0C as the target between",
                     "them. Control limits come from the process itself and are drawn on the",
                     "X-bar chart on the Fridge Detail page.")),
        plotlyOutput("hist_chart", height = "320px")
      ),
      bslib::card(
        bslib::card_header("Rolling 24-hour Ppk"),
        tags$p(class = "text-muted small mb-0",
               paste("Ppk recomputed over the trailing 96 readings - 24 hours at 15-minute",
                     "intervals - at each point, using only that window's own spread. It needs",
                     "at least 24 hours of data. A falling line means the fridge is getting",
                     "worse now, whatever the baseline says.")),
        plotlyOutput("rolling_chart", height = "320px")
      )
    )
  ),

  bslib::nav_panel(
    "Backup generator",
    uiOutput("generator_note"),
    bslib::card(plotlyOutput("gen_ind_chart", height = "320px"), full_screen = TRUE),
    bslib::card(plotlyOutput("gen_mr_chart", height = "260px"), full_screen = TRUE)
  ),

  bslib::nav_panel(
    "Data",
    bslib::layout_columns(
      col_widths = bslib::breakpoints(sm = 12, md = 4),
      fileInput("up_readings", "Readings (fridge_id, timestamp, temp_c, door_open, on_generator)", accept = ".csv"),
      fileInput("up_inventory", "Inventory (fridge_id, blood_type, blood_units)", accept = ".csv"),
      fileInput("up_generator", "Backup generator log (date, transfer_time_sec)", accept = ".csv")
    ),
    actionButton("load_demo", "Load demo data", class = "btn-primary mb-3"),
    uiOutput("data_status"),
    bslib::navset_card_tab(
      title = "Preview",
      bslib::nav_panel("Readings", DT::DTOutput("preview_readings")),
      bslib::nav_panel("Inventory", DT::DTOutput("preview_inventory")),
      bslib::nav_panel("Backup generator log", DT::DTOutput("preview_generator"))
    )
  ),

  bslib::nav_spacer(),
  bslib::nav_item(bslib::input_dark_mode(id = "color_mode"))
)

# ---- Server --------------------------------------------------------------------------------------

server <- function(input, output, session) {
  demo <- load_demo_data(data_dir)
  rv <- reactiveValues(
    readings = demo$readings, inventory = demo$inventory, backup_generator = demo$generator,
    from_readings = if (is.null(demo$readings)) "none" else "demo data",
    from_inventory = if (is.null(demo$inventory)) "none" else "demo data",
    from_backup_generator = if (is.null(demo$generator)) "none" else "demo data"
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
    }, error = function(e) {
      showNotification(paste0("Could not load ", label, ": ", conditionMessage(e)), type = "error", duration = 12)
    })
  }
  observeEvent(input$up_readings, try_upload(input$up_readings, prepare_readings, "readings", "readings"))
  observeEvent(input$up_inventory, try_upload(input$up_inventory, prepare_inventory, "inventory", "inventory"))
  observeEvent(input$up_generator, try_upload(input$up_generator, prepare_generator, "backup_generator", "backup generator log"))

  observeEvent(input$load_demo, {
    d <- load_demo_data(data_dir)
    if (is.null(d$readings)) {
      showNotification("Demo data not found. Expected data/readings.csv next to the app folder.", type = "error")
      return()
    }
    rv$readings <- d$readings
    rv$inventory <- d$inventory
    rv$backup_generator <- d$generator
    rv$from_readings <- rv$from_inventory <- rv$from_backup_generator <- "demo data"
    showNotification("Demo data loaded.", type = "message")
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
    choices <- stats::setNames(ids, fridge_label(ids))
    updateSelectInput(session, "fridge", choices = choices, selected = if (isTRUE(input$fridge %in% ids)) input$fridge else ids[1])
    updateSelectInput(session, "cap_fridge", choices = choices, selected = if (isTRUE(input$cap_fridge %in% ids)) input$cap_fridge else ids[1])
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
      class = "bbm-status rounded-3 p-3 px-4 mb-3",
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
      return(tags$div(class = "alert alert-info", "No readings loaded. Open the Data page and press Load demo data."))
    }
    s <- summary_numbers()
    over <- isTRUE(s$last_transfer > 10)
    transfer <- if (is.na(s$last_transfer)) "\u2014" else paste0(fmt_num(s$last_transfer, 1), " s")
    tagList(
      bslib::layout_columns(
        fill = FALSE,
        col_widths = bslib::breakpoints(sm = 12, md = 6),
        stat_box("Fridges needing action", s$needing_action, sprintf("of %d fridges, red or amber", length(analyses()))),
        stat_box("Blood units at risk", format(s$units_at_risk, big.mark = ","), "out of range now, or flagged in the last 24 h")
      ),
      bslib::layout_columns(
        fill = FALSE, class = "mt-3",
        col_widths = bslib::breakpoints(sm = 12, md = 6),
        stat_box("Average Ppk", fmt_num(s$average_ppk, 2), "The mean of each fridge\'s Ppk, counted in sigmas. Above 1.0 means the baseline temperatures fit inside 1\u20136 \u00B0C. Higher means a tighter fit.", quiet = TRUE),
        stat_box("Last backup test", transfer,
                 if (is.na(s$last_transfer)) "No backup test loaded." else "Last backup test \u00b7 team-chosen threshold (10 s); the manager sets it for their own site. Transfer time measures how many seconds it takes to switch to backup power.",
                 quiet = TRUE, value_class = if (over) "bbm-over" else NULL)
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
      mean_note <- if (isTRUE(a$has_limits) && !is.null(a$baseline$center)) {
        sprintf("Mean %.2f \u00B0C", a$baseline$center)
      } else {
        "No baseline mean yet"
      }
      bslib::card(
        fill = FALSE,
        bslib::card_header(
          class = "d-flex justify-content-between align-items-center",
          tags$strong(a$fridge_id), status_badge(a)
        ),
        plotlyOutput(paste0("spark_", safe_id(a$fridge_id)), height = "90px"),
        tags$div(
          class = "row text-center small g-1 mb-2",
          tags$div(class = "col-3", tags$div(class = "text-muted", "Blood units"), tags$strong(a$blood_units)),
          tags$div(class = "col-3", tags$div(class = "text-muted", "Ppk"), tags$strong(fmt_num(a$ppk, 2))),
          tags$div(class = "col-3", tags$div(class = "text-muted", "Out of spec in"), tags$strong(a$hours_text)),
          tags$div(class = "col-3", tags$div(class = "text-muted", "RPN"), tags$strong(a$rpn))
        ),
        tags$p(class = "text-muted small mb-1",
               paste("Blood units are the bags stored. Ppk is the room between this",
                     "fridge's readings and the nearer of 1 °C or 6 °C, counted in",
                     "sigmas. Out of spec in is the forecast time until the fitted line",
                     "reaches 1 °C or 6 °C.")),
        tags$p(class = "small mb-1",
               sprintf(paste("Risk priority number: severity %d × occurrence %d × urgency %d = %d.",
                             "Severity is the bag count banded 1 to 10, occurrence is the worst",
                             "special-cause pattern that fired, and urgency is how soon the forecast",
                             "reaches 1 °C or 6 °C. Higher acts first."),
                       a$severity, a$occurrence, a$urgency, a$rpn)),
        tags$p(class = "mb-0 small", a$flag_sentence)
      )
    })
    do.call(bslib::layout_columns,
            c(list(fill = FALSE, col_widths = bslib::breakpoints(sm = 12, md = 6, xl = 4)), unname(cards)))
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
    bloodtype_plot(bloodtype_data(), a$status_color, dark())
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

  output$capability_top <- renderUI({
    a <- cap()
    sentence <- if (a$capable_sentence %in% CAPABLE_SENTENCES) {
      paste0(fridge_label(a$fridge_id), " is ", a$capable_sentence, ".")
    } else {
      paste0(fridge_label(a$fridge_id), ": ", a$capable_sentence)
    }
    lag_text <- if (is.na(a$lag1)) "Lag-1 autocorrelation of the baseline: \u2014." else
      sprintf("Lag-1 autocorrelation of the baseline readings: %.2f. The limits assume independent readings; this is a limitation, not an adjustment.", a$lag1)

    # Backup generator statistics: a projection of what generator_analysis() already
    # computed. Nothing is derived here, so these match the Backup generator page.
    gs <- generator_stats(gen())
    gen_card <- if (is.null(gs)) {
      bslib::card(fill = FALSE,
        tags$h5(class = "mb-1", "Backup generator"),
        tags$p(class = "text-muted small mb-0",
               "No backup generator log loaded. Add one on the Data page to see the backup power statistics here."))
    } else {
      switchover <- if (is.na(gs$in_control)) "cannot say" else
        if (gs$in_control) "in control" else "investigate"
      bslib::card(fill = FALSE,
        tags$h5(class = "mb-1", "Backup generator"),
        tags$p(class = "text-muted small",
          paste("The backup generator carries the fridges through a mains outage.",
                "Transfer time is the number that matters: the seconds between the",
                "power failing and the backup generator picking up the load, and during that",
                "gap nothing is cooling, so the bags are exposed for exactly that long.")),
        bslib::layout_columns(
          fill = FALSE, col_widths = bslib::breakpoints(sm = 12, md = 3),
          bslib::value_box("Last transfer", fmt_num(gs$last, 1),
                           tags$small("seconds, from the most recent test")),
          bslib::value_box("Typical transfer", fmt_num(gs$typical, 1),
                           tags$small("seconds, the center of the chart")),
          bslib::value_box("Tests beyond the limits", sprintf("%d", gs$beyond),
                           tags$small(sprintf("of %d tests run", gs$n))),
          bslib::value_box("Switchover", switchover,
                           tags$small(if (is.na(gs$in_control)) gs$message
                                      else if (gs$in_control) "every test inside the limits"
                                      else sprintf("%d of %d tests beyond the limits", gs$beyond, gs$n)))
        ),
        tags$p(class = "text-muted small mb-0",
               "The 10 s line is a threshold the team chose, not a control limit."))
    }

    tagList(
      bslib::layout_columns(
        fill = FALSE, col_widths = bslib::breakpoints(sm = 12, md = 4),
        bslib::value_box("Cpk (short-term sigma)", fmt_num(a$cpk, 2),
          tags$small(paste("Room left if this fridge keeps holding temperature the way it",
                           "has been holding it hour to hour. Above 1.0 is room to spare;",
                           "below 1.0 it cannot reliably stay in spec."))),
        bslib::value_box("Ppk (overall sigma)", fmt_num(a$ppk, 2),
          tags$small(paste("The same room measured across the whole baseline, drift and",
                           "hour-to-hour shifts included. This is the long-run number."))),
        bslib::value_box("Gap (Cpk minus Ppk)", fmt_num(a$gap, 2),
          tags$small(paste("A stability signal, not a score. Near zero means the fridge is",
                           "steady. Clearly positive means it holds temperature within an",
                           "hour but wanders between hours, which is a stability problem",
                           "rather than a capability problem.")))
      ),
      bslib::card(fill = FALSE, tags$h4(class = "mb-1", sentence), tags$p(class = "text-muted small mb-0", lag_text)),
      gen_card
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
