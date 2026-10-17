# Risk priority number: RPN = severity * occurrence * urgency, each scored 1 to 10.
# No money anywhere: severity counts bags of blood.

check_score <- function(score, name) {
  if (length(score) != 1 || !is.numeric(score) || is.na(score) || score != round(score) ||
        score < 1 || score > 10) {
    stop(name, " must be a single whole number from 1 to 10")
  }
  invisible(score)
}

# Severity from the number of blood bags in the fridge.
severity_score <- function(blood_units) {
  if (length(blood_units) != 1 || !is.numeric(blood_units) || is.na(blood_units) || blood_units < 0) {
    stop("blood_units must be a single number, 0 or more")
  }
  upper <- c(0, 5, 15, 30, 50, 75, 100, 150, 200) # top of each band for scores 1 to 9; above 200 is 10
  hit <- which(blood_units <= upper)[1]
  if (is.na(hit)) 10 else hit
}

# Occurrence: how bad is the worst signal. The caller chooses the integer; this function only checks it.
# Scale:
# 1 none and in spec; 2 test 6; 3 test 5 or 8; 4 test 4; 5 test 2; 6 test 7; 7 test 3; 8 range-chart test 1; 9 X-bar test 1 while inside spec; 10 any reading outside 1 to 6 C.
occurrence_score <- function(worst) {
  check_score(worst, "worst")
  worst
}

# Map the signals to the occurrence integer, taking the maximum.
# xbar_flags: a list of 8 index vectors, element k holding the flagged indices from X-bar test k.
# range_test1: TRUE/FALSE (or the flagged indices) from range-chart test 1.
# any_out_of_spec: TRUE if any reading was outside 1 to 6 C.
worst_occurrence <- function(xbar_flags, range_test1, any_out_of_spec) {
  if (!is.list(xbar_flags) || length(xbar_flags) != 8) {
    stop("xbar_flags must be a list of 8 index vectors, one per test")
  }
  if (isTRUE(any_out_of_spec)) {
    return(10)
  }
  score_for_test <- c(9, 5, 7, 4, 3, 2, 6, 3) # tests 1 to 8, see the scale above
  present <- vapply(xbar_flags, function(idx) length(idx) > 0, logical(1))
  range_flagged <- if (is.logical(range_test1)) any(range_test1) else length(range_test1) > 0

  worst <- 1
  if (any(present)) worst <- max(worst, score_for_test[present])
  if (range_flagged) worst <- max(worst, 8)
  worst
}

# Urgency from the hours until the line reaches the spec (0 = already out, Inf = never).
urgency_score <- function(hours) {
  if (length(hours) != 1 || !is.numeric(hours) || is.na(hours) || hours < 0) {
    stop("hours must be a single number, 0 or more (Inf means no crossing)")
  }
  upper <- c(2, 4, 8, 12, 18, 24, 36, 48, 72) # scores 10 down to 2; above 72 is 1
  hit <- which(hours <= upper)[1]
  if (is.na(hit)) 1 else 11 - hit
}

rpn <- function(severity, occurrence, urgency) {
  check_score(severity, "severity")
  check_score(occurrence, "occurrence")
  check_score(urgency, "urgency")
  severity * occurrence * urgency
}
