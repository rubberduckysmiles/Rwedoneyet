# H-32: the card sentence must describe the day the badge judged.
#
# flag_sentence used to be the meaning of the most recent flag ANYWHERE after the
# baseline, so it ignored the 24-hour window the badge and units_at_risk both use. On
# the shipped demo data that made the Overview contradict itself: F01 and F04 were
# green while their sentences described shifts from days earlier, and F05 was amber
# with the same sentence as green F01.
#
# Everything below was MEASURED from the committed files with load_demo_data() plus
# analyze_all() - the same two calls app.R makes - and never assumed. The first three
# expectations are the exact three cases that exposed the defect, so this file fails
# against the old code on purpose.
library(testthat)

path <- if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R"
source(path)

# The card sentence is about the badge's window, and the badge is decided on the
# bundled demo the live app shows. app/data is the copy that ships.
app_data <- if (dir.exists("app/data")) "app/data" else "../app/data"

demo <- load_demo_data(app_data)
analyses <- analyze_all(demo$readings, demo$inventory)

# n_subgroups and the start of the 24-hour window, the same arithmetic monitor.R uses.
window_start <- function(id) {
  r <- demo$readings[demo$readings$fridge_id == id, , drop = FALSE]
  r <- r[order(r$timestamp), , drop = FALSE]
  st <- subgroup_stats(r$temp_c, 4)
  st <- st[st$n_obs == 4, , drop = FALSE]
  nrow(st) - 24
}

# The subgroup and meaning a sentence came from, so a stale sentence is visible rather
# than merely wrong. Returns NA when the fridge has no flag in the badge's window.
sentence_source <- function(a, id) {
  r <- demo$readings[demo$readings$fridge_id == id, , drop = FALSE]
  r <- r[order(r$timestamp), , drop = FALSE]
  st <- subgroup_stats(r$temp_c, 4)
  st <- st[st$n_obs == 4, , drop = FALSE]
  n_sub <- nrow(st)
  recent_start <- n_sub - 24

  v <- a$violations[a$violations$monitored & a$violations$subgroup > recent_start, , drop = FALSE]
  if (nrow(v) == 0) {
    return(list(subgroup = NA_integer_, meaning = NA_character_))
  }
  latest <- v[v$subgroup == max(v$subgroup), , drop = FALSE]
  list(subgroup = max(v$subgroup), meaning = latest$meaning[which.min(latest$test)])
}

test_that("the three cases that exposed the defect now read correctly", {
  # F01: green, and its only nearby flag is three days stale. The old sentence claimed
  # a shift. A green card must not say the fridge has shifted.
  f01 <- analyses$F01
  expect_equal(f01$status, "green")
  expect_false(grepl("shifted", f01$flag_sentence, fixed = TRUE))
  expect_false(grepl("shift", f01$flag_sentence, fixed = TRUE))

  # F04: green, its last flag is outside the window. Same claim, same defect.
  f04 <- analyses$F04
  expect_equal(f04$status, "green")
  expect_false(grepl("shift", f04$flag_sentence, fixed = TRUE))

  # F05: amber, and its amber comes from test 2. The card must say which pattern made
  # it amber - this is the case that could not be explained from the card at all.
  f05 <- analyses$F05
  expect_equal(f05$status, "amber")
  expect_match(f05$flag_sentence, "Nine points in a row", fixed = TRUE)
  expect_match(f05$flag_sentence, "shifted", fixed = TRUE)
})

test_that("a card sentence always comes from inside the badge's window", {
  for (id in names(analyses)) {
    a <- analyses[[id]]
    src <- sentence_source(a, id)
    if (!is.na(src$subgroup)) {
      expect_gt(src$subgroup, window_start(id))
      expect_lte(src$subgroup, window_start(id) + 24)
      # And the sentence really is that flag's meaning, not something else.
      expect_equal(a$flag_sentence, src$meaning, info = id)
    } else {
      # No flag in the window: the sentence must be the neutral one.
      expect_equal(a$flag_sentence, "No special-cause flag.", info = id)
    }
  }
})

test_that("a green fridge never carries an alarming sentence, and amber always explains itself", {
  for (id in names(analyses)) {
    a <- analyses[[id]]
    if (a$status == "green") {
      # Green means nothing in the window. The sentence must not describe a disturbance.
      expect_false(grepl("shift", a$flag_sentence, fixed = TRUE), info = id)
      expect_false(grepl("excursion", a$flag_sentence, fixed = TRUE), info = id)
      expect_false(grepl("stuck sensor", a$flag_sentence, fixed = TRUE), info = id)
    }
    if (a$status == "amber") {
      # Amber was chosen by a countable condition, so the sentence must be less than
      # the neutral wording: something fired in the window and the card says so.
      expect_false(grepl("No special-cause flag", a$flag_sentence, fixed = TRUE), info = id)
    }
  }
})

test_that("the sentence is one of the known test meanings or the neutral one", {
  meanings <- c(
    "One point outside the 3-sigma limits. A sudden temperature excursion.",
    "Nine points in a row on one side of the center. The fridge has shifted.",
    "Six points in a row steadily rising or falling.",
    "Fourteen points in a row alternating up and down.",
    "Two of three points beyond 2 sigma, on the same side. A shift is starting.",
    "Four of five points beyond 1 sigma, on the same side.",
    "Fifteen points in a row inside 1 sigma. Possible stuck sensor.",
    "Eight points in a row beyond 1 sigma.",
    "No special-cause flag."
  )
  for (id in names(analyses)) {
    expect_true(analyses[[id]]$flag_sentence %in% meanings,
                info = sprintf("%s: %s", id, analyses[[id]]$flag_sentence))
  }
})

test_that("H-32 moved no verdict and no number", {
  # The whole point of H-32: the rule and every published number stay exactly as
  # H-26 measured them. Only the sentence changes.
  expect_equal(sum(vapply(analyses, function(a) a$status != "green", logical(1))), 4L)
  expect_equal(names(analyses)[vapply(analyses, function(a) a$status == "red", logical(1))],
               c("F02", "F03"))
  expect_equal(sum(vapply(analyses, function(a) a$units_at_risk, numeric(1))), 283)
  got_cpk <- vapply(analyses, function(a) round(a$cpk, 3), numeric(1))
  got_rpn <- vapply(analyses, function(a) a$rpn, numeric(1))
  expect_equal(unname(got_cpk[order(names(got_cpk))]),
               c(5.474, 6.151, 5.813, 6.281, 4.947, 5.913))
  expect_equal(unname(got_rpn[order(names(got_rpn))]),
               c(15, 900, 50, 100, 18, 54))
})

test_that("footnote: a clean window on an unstable chart still says so honestly", {
  # any_flag_post keeps its whole-chart meaning, so a green fridge with a stale flag can
  # still be described as not stable in the capability sentence. That is deliberate and
  # is a different sentence from the card's flag_sentence.
  f01 <- analyses$F01
  expect_equal(f01$status, "green")
  expect_equal(f01$capable_sentence, "inside the spec width, but not stable")
  expect_equal(f01$flag_sentence, "No special-cause flag.")
})
