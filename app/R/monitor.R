# Monitor: joins the existing statistics into one result per fridge, for the Shiny screens.
# There are NO new formulas here. Every limit, index, test, forecast and score comes from a function
# in the other files of app/R/ (freeze_baseline, subgroup_stats, special_cause_test_1 to _8,
# hours_to_spec, rolling_ppk, severity_score, worst_occurrence, urgency_score, rpn, imr_limits).
# This file only decides which numbers go together, reads CSV files, and picks a badge.

SPEC_LOW <- 1 # safe storage range for red cells, degrees C
SPEC_HIGH <- 6
TARGET_TEMP <- 3.5 # the middle of the spec; it is not the control-chart center

# Colors are used only for status.
STATUS_COLORS <- c(green = "#2E9E6B", amber = "#E8A33D", red = "#D64045", gray = "#8A8F98")
STATUS_LABELS <- c(
  green = "Green: leave it",
  amber = "Amber: watch",
  red = "Red: act this shift",
  gray = "No limits yet"
)

# blood_type is optional so a manager's own totals-only sheet still loads; the demo file has it.
INVENTORY_COLUMNS <- c("fridge_id", "blood_units")
GENERATOR_COLUMNS <- c("date", "transfer_time_sec")

# ---- Reading files -------------------------------------------------------------------------------

check_columns <- function(df, needed, what) {
  missing_cols <- setdiff(needed, names(df))
  if (length(missing_cols) > 0) {
    stop(what, " is missing column(s): ", paste(missing_cols, collapse = ", "),
         ". Expected: ", paste(needed, collapse = ", "), ".")
  }
  invisible(df)
}

parse_timestamp <- function(x) {
  out <- as.POSIXct(as.character(x), format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
  if (anyNA(out)) {
    retry <- tryCatch(
      as.POSIXct(as.character(x), tz = "UTC",
                 tryFormats = c("%Y-%m-%d %H:%M", "%Y-%m-%dT%H:%M:%S", "%Y/%m/%d %H:%M:%S", "%Y/%m/%d %H:%M")),
      error = function(e) rep(as.POSIXct(NA), length(x))
    )
    out[is.na(out)] <- retry[is.na(out)]
  }
  out
}

# Readings: needs fridge_id, timestamp, temp_c (door_open and on_generator are kept if present).
# Rows with a missing time or temperature are dropped. Result is sorted by fridge, then time.
prepare_readings <- function(df) {
  check_columns(df, c("fridge_id", "timestamp", "temp_c"), "readings file")
  out <- data.frame(
    fridge_id = as.character(df$fridge_id),
    timestamp = parse_timestamp(df$timestamp),
    temp_c = suppressWarnings(as.numeric(df$temp_c)),
    stringsAsFactors = FALSE
  )
  for (col in c("door_open", "on_generator")) {
    out[[col]] <- if (col %in% names(df)) suppressWarnings(as.integer(df[[col]])) else NA_integer_
  }
  keep <- !is.na(out$timestamp) & !is.na(out$temp_c) & !is.na(out$fridge_id) & nzchar(out$fridge_id)
  if (!any(keep)) stop("readings file has no usable rows (need a timestamp like 2026-10-01 00:00:00 and a number in temp_c).")
  out <- out[keep, , drop = FALSE]
  out <- out[order(out$fridge_id, out$timestamp), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Inventory: fridge_id and blood_units are required. blood_type is kept when present
# (one row per fridge per type); when it is missing the file is totals-only and the
# breakdown screens simply have nothing to draw. Rows with a blank type label are kept
# but labelled "untyped" so no bag is ever dropped from a count.
prepare_inventory <- function(df) {
  check_columns(df, INVENTORY_COLUMNS, "inventory file")
  out <- data.frame(
    fridge_id = as.character(df$fridge_id),
    blood_units = suppressWarnings(as.numeric(df$blood_units)),
    stringsAsFactors = FALSE
  )
  out$blood_type <- if ("blood_type" %in% names(df)) {
    bt <- trimws(as.character(df$blood_type))
    bt[is.na(df$blood_type) | !nzchar(bt)] <- "untyped"
    bt
  } else {
    rep("untyped", nrow(out))
  }
  out <- out[!is.na(out$fridge_id) & !is.na(out$blood_units) & out$blood_units >= 0, , drop = FALSE]
  out <- out[, c("fridge_id", "blood_type", "blood_units")]
  rownames(out) <- NULL
  out
}

prepare_generator <- function(df) {
  check_columns(df, GENERATOR_COLUMNS, "generator log")
  out <- data.frame(
    date = as.character(df$date),
    transfer_time_sec = suppressWarnings(as.numeric(df$transfer_time_sec)),
    stringsAsFactors = FALSE
  )
  out <- out[!is.na(out$transfer_time_sec), , drop = FALSE]
  dates <- suppressWarnings(as.Date(out$date))
  if (nrow(out) > 0 && !anyNA(dates)) out <- out[order(dates), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Reads the three demo CSVs from data_dir. A file that is missing gives NULL for that part.
load_demo_data <- function(data_dir) {
  read_one <- function(name, prepare) {
    path <- file.path(data_dir, name)
    if (!file.exists(path)) return(NULL)
    tryCatch(prepare(utils::read.csv(path, stringsAsFactors = FALSE)), error = function(e) NULL)
  }
  list(
    readings = read_one("readings.csv", prepare_readings),
    inventory = read_one("inventory.csv", prepare_inventory),
    generator = read_one("generator_log.csv", prepare_generator)
  )
}

# ---- One fridge ----------------------------------------------------------------------------------

keep_after <- function(indices, n_baseline) {
  indices <- as.integer(indices)
  indices[indices > n_baseline]
}

# TRUE when two of these subgroup numbers are adjacent, which is a run of two in a row:
# the subgroup numbers are sequential, so "adjacent" means "the next hour".
two_in_a_row <- function(indices) {
  indices <- sort(as.integer(indices))
  any(diff(indices) == 1L)
}

format_hours <- function(h) {
  if (length(h) != 1 || is.na(h)) return("\u2014")
  if (is.infinite(h)) return("no crossing")
  if (h <= 0) return("already out")
  if (h > 72) return("> 72 h") # urgency treats anything past 72 hours as the lowest score
  sprintf("%.0f h", h)
}

# readings: data frame for ONE fridge (timestamp, temp_c). blood_units: bags in that fridge.
# Returns everything a screen needs. Subgroups are the complete hours only.
analyze_fridge <- function(fridge_id, readings, blood_units = 0, subgroup_n = 4,
                           baseline_subgroups = 48, min_subgroups = 25) {
  readings <- readings[order(readings$timestamp), , drop = FALSE]
  values <- readings$temp_c
  if (length(blood_units) != 1 || is.na(blood_units) || blood_units < 0) blood_units <- 0

  fb <- freeze_baseline(values, subgroup_n, baseline_subgroups, min_subgroups)
  has_limits <- !is.null(fb$limits)
  n_base <- fb$n_baseline_subgroups

  st <- subgroup_stats(values, subgroup_n)
  st <- st[st$n_obs == subgroup_n, , drop = FALSE]
  st$time <- readings$timestamp[(st$subgroup - 1) * subgroup_n + 1]
  st$baseline <- st$subgroup <= n_base
  n_sub <- nrow(st)

  # The eight tests on the X-bar series (all subgroup means), then test 1 on the ranges.
  tests <- NULL
  range_test <- list(indices = integer(0), meaning = "")
  if (has_limits && n_sub > 0) {
    m <- st$mean
    ctr <- fb$limits$xbar$center
    se <- fb$limits$xbar$se
    tests <- list(
      special_cause_test_1(m, fb$limits$xbar$lcl, fb$limits$xbar$ucl),
      special_cause_test_2(m, ctr),
      special_cause_test_3(m),
      special_cause_test_4(m),
      special_cause_test_5(m, ctr, se),
      special_cause_test_6(m, ctr, se),
      special_cause_test_7(m, ctr, se),
      special_cause_test_8(m, ctr, se)
    )
    range_test <- special_cause_test_1(st$range, fb$limits$range$lcl, fb$limits$range$ucl)
  }
  if (is.null(tests)) {
    tests <- lapply(1:8, function(k) list(indices = integer(0), meaning = ""))
  }

  # Test 1 on the subgroup standard deviations. DISPLAY ONLY: these flags are
  # drawn on their own chart and deliberately feed nothing else - not the
  # violations table, not the badge, not the RPN, not units_at_risk.
  sd_test <- list(indices = integer(0), meaning = "")
  sd_flagged <- rep(FALSE, n_sub)
  if (has_limits && n_sub > 0) {
    sd_test <- special_cause_test_1(st$sd, fb$limits$sd$lcl, fb$limits$sd$ucl)
    sd_flagged[sd_test$indices] <- TRUE
  }

  # Table of every flag, with whether it falls after the baseline (monitored).
  rows <- list()
  for (k in 1:8) {
    idx <- tests[[k]]$indices
    if (length(idx) > 0) {
      rows[[length(rows) + 1]] <- data.frame(
        chart = "X-bar", subgroup = idx, time = st$time[idx], test = k,
        meaning = tests[[k]]$meaning, monitored = idx > n_base, stringsAsFactors = FALSE
      )
    }
  }
  if (length(range_test$indices) > 0) {
    idx <- range_test$indices
    rows[[length(rows) + 1]] <- data.frame(
      chart = "Range", subgroup = idx, time = st$time[idx], test = 1,
      meaning = range_test$meaning, monitored = idx > n_base, stringsAsFactors = FALSE
    )
  }
  violations <- if (length(rows) > 0) do.call(rbind, rows) else {
    data.frame(chart = character(0), subgroup = integer(0), time = as.POSIXct(character(0), tz = "UTC"),
               test = integer(0), meaning = character(0), monitored = logical(0), stringsAsFactors = FALSE)
  }
  violations <- violations[order(violations$time, violations$test), , drop = FALSE]
  rownames(violations) <- NULL

  # Smallest test number that flagged each subgroup (NA = none).
  xbar_min_test <- rep(NA_integer_, n_sub)
  for (k in 8:1) xbar_min_test[tests[[k]]$indices] <- k
  range_flagged <- rep(FALSE, n_sub)
  range_flagged[range_test$indices] <- TRUE

  # Flags after the baseline only.
  post_xbar <- lapply(tests, function(t) keep_after(t$indices, n_base))
  post_range <- keep_after(range_test$indices, n_base)
  any_flag_post <- any(lengths(post_xbar) > 0) || length(post_range) > 0

  # Forecast on post-baseline means only.
  post_means <- st$mean[st$subgroup > n_base]
  forecast <- if (has_limits) hours_to_spec(post_means, SPEC_LOW, SPEC_HIGH) else {
    list(hours = NA_real_, slope = NA_real_, intercept = NA_real_, message = "no baseline limits yet")
  }
  hours <- forecast$hours

  last96 <- utils::tail(values, 96)
  out_last_24h <- any(last96 < SPEC_LOW | last96 > SPEC_HIGH, na.rm = TRUE)
  latest_out <- length(values) > 0 && isTRUE(utils::tail(values, 1) < SPEC_LOW || utils::tail(values, 1) > SPEC_HIGH)
  post_readings <- if (has_limits) values[-seq_len(n_base * subgroup_n)] else numeric(0)
  any_out_post <- any(post_readings < SPEC_LOW | post_readings > SPEC_HIGH, na.rm = TRUE)

  cpk <- if (has_limits) fb$capability$cpk else NA_real_
  ppk <- if (has_limits) fb$capability$ppk else NA_real_
  gap <- if (has_limits) fb$capability$gap else NA_real_

  # Badge. Act on the last 24 subgroups (one day) - the same window that decides which bags
  # are at risk - and never on one lone flag. Eight tests run on about 120 post-baseline
  # subgroups, so "any flag anywhere" fires on nearly every healthy fridge: 92% of 200
  # simulated healthy fleets under the old rule, 15.5% under this one (demo/alert_rate.R).
  # Inside that day, red needs a reading outside 1-6 C or two test-1 points in a row, and
  # amber needs two flags in the day. Cpk below 1 and a crossing within 12 hours still
  # count, so a slow problem stays visible while it is still inside the spec width.
  recent_start <- n_sub - 24
  flags_post <- sort(unique(c(unlist(post_xbar), post_range)))
  flags_recent <- flags_post[flags_post > recent_start]
  if (out_last_24h || two_in_a_row(post_xbar[[1]][post_xbar[[1]] > recent_start])) {
    status <- "red"
  } else if (!has_limits) {
    status <- "gray"
  } else if (length(flags_recent) >= 2 || isTRUE(cpk < 1) || (is.finite(hours) && hours <= 12)) {
    status <- "amber"
  } else {
    status <- "green"
  }

  # Units at risk: the bags in this fridge if it is out now, or any flag in the last 24 hourly
  # subgroups. One recent flag is enough here even though the badge now needs two: the count is
  # about bags exposed to a disturbance, not about which fridge the manager opens first.
  flag_last_24h <- any(unlist(post_xbar) > recent_start) || any(post_range > recent_start)
  units_at_risk <- if (latest_out || flag_last_24h) blood_units else 0

  # Sentence for the card. It must describe the same day the badge judged, or the card
  # contradicts the badge beside it: F01 and F04 are green here, and their nearest flags
  # are subgroups 94 and 137, three days and two days before the last reading. The old
  # sentence read the newest flag anywhere after the baseline, so those green cards
  # claimed a shift. Report the newest flag INSIDE the window; when the window is clean,
  # say so, even though any_flag_post may still keep the whole chart "not stable" in the
  # capability sentence above.
  in_window <- violations[violations$monitored & violations$subgroup > recent_start, , drop = FALSE]
  flag_sentence <- "No special-cause flag."
  if (nrow(in_window) > 0) {
    latest <- in_window[in_window$subgroup == max(in_window$subgroup), , drop = FALSE]
    flag_sentence <- latest$meaning[which.min(latest$test)]
  }

  # Capable sentence.
  capable_sentence <- if (!has_limits) {
    fb$message
  } else if (is.na(cpk)) {
    fb$capability$message
  } else if (cpk >= 1 && !any_flag_post) {
    "capable and stable"
  } else if (cpk >= 1) {
    "inside the spec width, but not stable"
  } else {
    "not capable"
  }

  # Risk priority number.
  occurrence <- worst_occurrence(post_xbar, post_range, any_out_post)
  urgency <- urgency_score(if (is.na(hours)) Inf else hours)
  severity <- severity_score(blood_units)
  risk <- rpn(severity, occurrence, urgency)

  roll <- rolling_ppk(values, SPEC_LOW, SPEC_HIGH, 96)
  roll_time <- if (length(roll) > 0) readings$timestamp[96:length(values)] else as.POSIXct(character(0), tz = "UTC")

  base_readings <- if (has_limits) values[seq_len(n_base * subgroup_n)] else numeric(0)

  list(
    fridge_id = fridge_id,
    baseline = fb,
    has_limits = has_limits,
    n_baseline = n_base,
    subgroups = st,
    tests = tests,
    range_test = range_test,
    xbar_min_test = xbar_min_test,
    range_flagged = range_flagged,
    sd_flagged = sd_flagged,
    sd_test = sd_test,
    violations = violations,
    forecast = forecast,
    hours = hours,
    hours_text = format_hours(hours),
    status = status,
    status_color = unname(STATUS_COLORS[status]),
    status_label = unname(STATUS_LABELS[status]),
    cpk = cpk, ppk = ppk, gap = gap,
    lag1 = if (has_limits) fb$lag1 else NA_real_,
    blood_units = blood_units,
    units_at_risk = units_at_risk,
    flag_sentence = flag_sentence,
    capable_sentence = capable_sentence,
    severity = severity, occurrence = occurrence, urgency = urgency, rpn = risk,
    rolling_ppk = roll, rolling_time = roll_time,
    base_readings = base_readings,
    readings = readings
  )
}

# ---- All fridges ---------------------------------------------------------------------------------

# Returns a list of analyses, one per fridge, sorted by RPN (highest first).
# The inventory may hold one row per fridge per blood type, so a fridge's bag
# count is the SUM of its rows, never the first row alone.
analyze_all <- function(readings, inventory = NULL) {
  if (is.null(readings) || nrow(readings) == 0) return(list())
  ids <- sort(unique(readings$fridge_id))
  out <- lapply(ids, function(id) {
    units <- 0
    if (!is.null(inventory)) {
      hit <- inventory$blood_units[inventory$fridge_id == id]
      if (length(hit) > 0) units <- sum(hit)
    }
    analyze_fridge(id, readings[readings$fridge_id == id, , drop = FALSE], units)
  })
  names(out) <- ids
  rpns <- vapply(out, function(a) a$rpn, numeric(1))
  out[order(-rpns, ids)]
}

# Four numbers for the Overview boxes.
overview_summary <- function(analyses, generator = NULL) {
  status <- vapply(analyses, function(a) a$status, character(1))
  ppks <- vapply(analyses, function(a) a$ppk, numeric(1))
  last_transfer <- NA_real_
  if (!is.null(generator) && nrow(generator) > 0) last_transfer <- utils::tail(generator$transfer_time_sec, 1)
  list(
    needing_action = sum(status %in% c("red", "amber")),
    units_at_risk = sum(vapply(analyses, function(a) a$units_at_risk, numeric(1))),
    average_ppk = if (any(!is.na(ppks))) mean(ppks, na.rm = TRUE) else NA_real_,
    last_transfer = last_transfer
  )
}

# ---- Blood types -------------------------------------------------------------------------------

# One row per blood type held in one fridge: how many bags, what share of that fridge's
# stock, and how many of those bags are at risk. No new formula: it groups counts that
# are already in the inventory and divides by the fridge's own total.
# Risk is judged PER FRIDGE (analyze_fridge flags the whole fridge or none of it), so a
# type's at-risk bags are that type's own count when the fridge is at risk, and 0 when it
# is not. Types are sorted by bag count, highest first. A fridge with no inventory rows
# returns zero rows, never an error.
bloodtype_table <- function(inventory, fridge_id, units_at_risk = 0) {
  empty <- data.frame(blood_type = character(0), blood_units = numeric(0),
                      share = numeric(0), units_at_risk = numeric(0),
                      stringsAsFactors = FALSE)
  if (is.null(inventory) || nrow(inventory) == 0 || length(fridge_id) != 1 || is.na(fridge_id)) {
    return(empty)
  }
  rows <- inventory[inventory$fridge_id == fridge_id, , drop = FALSE]
  if (nrow(rows) == 0) return(empty)

  # One sheet could name the same type twice; add those rows together.
  # method = "radix" sorts by byte order, not the machine's collation, so a tie
  # between AB+ and AB- comes out the same on every computer.
  types <- sort(unique(rows$blood_type), method = "radix")
  counts <- vapply(types, function(t) sum(rows$blood_units[rows$blood_type == t]), numeric(1))
  keep <- counts > 0
  types <- types[keep]
  counts <- counts[keep]
  if (length(counts) == 0) return(empty)

  total <- sum(counts)
  if (length(units_at_risk) != 1 || is.na(units_at_risk) || units_at_risk < 0) units_at_risk <- 0
  # The whole fridge is at risk or none of it is, so at-risk bags split across types in
  # proportion to their own counts. For the 0 or all values analyze_fridge produces,
  # this is exactly 0 or exactly the type's count.
  at_risk <- counts * min(1, units_at_risk / total)

  out <- data.frame(blood_type = types, blood_units = counts,
                    share = counts / total, units_at_risk = at_risk,
                    stringsAsFactors = FALSE)
  out[order(-out$blood_units, out$blood_type, method = "radix"), , drop = FALSE]
}

# ---- Generator -----------------------------------------------------------------------------------

generator_analysis <- function(generator) {
  if (is.null(generator) || nrow(generator) == 0) return(NULL)
  x <- generator$transfer_time_sec
  lim <- imr_limits(x)
  flagged <- if (is.na(lim$lcl)) integer(0) else special_cause_test_1(x, lim$lcl, lim$ucl)$indices
  # moving range = gap between neighbouring transfers (the series that imr_limits draws its limits for)
  list(limits = lim, flagged = flagged, n = length(x), x = x, labels = generator$date,
       moving_range = c(NA_real_, abs(diff(x))))
}

# ---- Chart helpers (offsets from the limits that xbar_limits already computed) -------------------

# Zone bands for the X-bar chart: center plus or minus the zone distances given by xbar_limits.
zone_bands <- function(xbar) {
  ctr <- xbar$center
  d <- c(xbar$zone1, xbar$zone2, xbar$zone3)
  data.frame(
    zone = c("C", "B", "A", "C", "B", "A"),
    y0 = c(ctr, ctr + d[1], ctr + d[2], ctr - d[1], ctr - d[2], ctr - d[3]),
    y1 = c(ctr + d[1], ctr + d[2], ctr + d[3], ctr, ctr - d[1], ctr - d[2]),
    depth = c(1, 2, 3, 1, 2, 3)
  )
}
