# Eight special-cause tests for a control chart.
# Each takes the plotted values in time order and returns
#   list(indices = integer vector of flagged positions (maybe empty), meaning = one sentence).
# The tests do not call each other. A point exactly on a line is never a flag: every comparison is strict.
# A missing value (NA) never counts toward a pattern and breaks any run.

# TRUE where the value is strictly more than k * se above center (side = 1) or below it (side = -1).
beyond_side <- function(values, center, se, k, side) {
  d <- side * (values - center)
  !is.na(d) & d > k * se
}

# Positions where a run of TRUE has reached at least `need` in a row (the need-th point and each extension).
run_end_positions <- function(condition, need) {
  run <- 0L
  hit <- logical(length(condition))
  for (i in seq_along(condition)) {
    run <- if (isTRUE(condition[i])) run + 1L else 0L
    hit[i] <- run >= need
  }
  which(hit)
}

# Positions i (the last point of a window) where at least `need` of the last `width` points satisfy `condition`.
window_end_positions <- function(condition, width, need) {
  hits <- integer(0)
  condition <- !is.na(condition) & condition
  if (length(condition) >= width) {
    for (i in width:length(condition)) {
      if (sum(condition[(i - width + 1):i]) >= need) hits <- c(hits, i)
    }
  }
  hits
}

# Test 1: one point outside the control limits.
special_cause_test_1 <- function(values, lower, upper) {
  outside <- !is.na(values) & (values < lower | values > upper)
  list(
    indices = as.integer(which(outside)),
    meaning = "One point outside the 3-sigma limits. A sudden temperature excursion."
  )
}

# Test 2: nine points in a row strictly on the same side of the center. A point on the center breaks the run.
special_cause_test_2 <- function(values, center) {
  above <- !is.na(values) & values > center
  below <- !is.na(values) & values < center
  hits <- sort(unique(c(run_end_positions(above, 9), run_end_positions(below, 9))))
  list(
    indices = as.integer(hits),
    meaning = "Nine points in a row on one side of the center. The fridge has shifted."
  )
}

# Test 3: six points in a row strictly rising, or six strictly falling. Equal neighbours break the run.
special_cause_test_3 <- function(values) {
  n <- length(values)
  rising <- logical(n)
  falling <- logical(n)
  if (n >= 2) {
    rising[2:n] <- !is.na(values[2:n]) & !is.na(values[1:(n - 1)]) & values[2:n] > values[1:(n - 1)]
    falling[2:n] <- !is.na(values[2:n]) & !is.na(values[1:(n - 1)]) & values[2:n] < values[1:(n - 1)]
  }
  # Six points in a row means five steps in a row, so a run of 5 steps flags its last point.
  hits <- sort(unique(c(run_end_positions(rising, 5), run_end_positions(falling, 5))))
  list(
    indices = as.integer(hits),
    meaning = "Six points in a row steadily rising or falling. Possible compressor wear."
  )
}

# Test 4: fourteen points in a row alternating up and down. An equal pair breaks the run.
special_cause_test_4 <- function(values) {
  n <- length(values)
  # run[i] = how many points the current alternating run has, counting point i
  run <- integer(n)
  for (i in seq_len(n)) {
    if (i == 1) {
      run[i] <- 1L
    } else {
      step <- values[i] - values[i - 1]
      if (is.na(step) || step == 0) {
        run[i] <- 1L
      } else if (i >= 3 && run[i - 1] >= 2 && isTRUE(step * (values[i - 1] - values[i - 2]) < 0)) {
        run[i] <- run[i - 1] + 1L
      } else {
        run[i] <- 2L
      }
    }
  }
  list(
    indices = as.integer(which(run >= 14)),
    meaning = "Fourteen points in a row alternating up and down. The controller is hunting."
  )
}

# Test 5: at least 2 of 3 points in a row strictly beyond 2 sigma, on the same side. Flags the last point of each window.
special_cause_test_5 <- function(values, center, se) {
  high <- window_end_positions(beyond_side(values, center, se, 2, 1), 3, 2)
  low <- window_end_positions(beyond_side(values, center, se, 2, -1), 3, 2)
  list(
    indices = as.integer(sort(unique(c(high, low)))),
    meaning = "Two of three points beyond 2 sigma, on the same side. A shift is starting."
  )
}

# Test 6: at least 4 of 5 points in a row strictly beyond 1 sigma, on the same side. Flags the last point of each window.
special_cause_test_6 <- function(values, center, se) {
  high <- window_end_positions(beyond_side(values, center, se, 1, 1), 5, 4)
  low <- window_end_positions(beyond_side(values, center, se, 1, -1), 5, 4)
  list(
    indices = as.integer(sort(unique(c(high, low)))),
    meaning = "Four of five points beyond 1 sigma, on the same side. A small sustained shift."
  )
}

# Test 7: fifteen points in a row strictly inside 1 sigma of the center, either side.
special_cause_test_7 <- function(values, center, se) {
  inside <- !is.na(values) & abs(values - center) < se
  list(
    indices = as.integer(run_end_positions(inside, 15)),
    meaning = "Fifteen points in a row inside 1 sigma. Possible stuck sensor."
  )
}

# Test 8: eight points in a row all strictly beyond 1 sigma of the center, on either side (sides may mix).
special_cause_test_8 <- function(values, center, se) {
  outside <- !is.na(values) & abs(values - center) > se
  list(
    indices = as.integer(run_end_positions(outside, 8)),
    meaning = "Eight points in a row all outside 1 sigma. Two regimes mixed together."
  )
}
