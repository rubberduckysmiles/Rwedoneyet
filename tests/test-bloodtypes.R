source(if (file.exists("app/qc.R")) "app/qc.R" else "../app/qc.R") # works from the repo root and from inside tests/
library(testthat)

inv_path <- if (file.exists("data/inventory.csv")) "data/inventory.csv" else "../data/inventory.csv"

demo_inventory <- prepare_inventory(utils::read.csv(inv_path, stringsAsFactors = FALSE))

# The fridge totals fixed in SPEC section 7 and data/README.md: F01..F06.
OLD_TOTALS <- c(F01 = 12, F02 = 180, F03 = 40, F04 = 220, F05 = 8, F06 = 55)

# A fridge whose badge makes all of its bags at risk (last reading outside 1-6 C).
spike_readings <- function(id, last_temp = 3.5) {
  data.frame(fridge_id = id,
             timestamp = as.POSIXct("2026-10-01 00:00:00", tz = "UTC") + 0:671 * 900,
             temp_c = c(rep(3.5, 671), last_temp),
             door_open = 0L, on_generator = 0L,
             stringsAsFactors = FALSE)
}

test_that("the demo inventory keeps every fridge's original bag total", {
  totals <- tapply(demo_inventory$blood_units, demo_inventory$fridge_id, sum)
  expect_equal(as.numeric(totals[names(OLD_TOTALS)]), as.numeric(OLD_TOTALS))
})

test_that("analyze_all still reads the same totals out of the per-type file", {
  a <- analyze_all(spike_readings("F02"), demo_inventory)
  expect_equal(a[["F02"]]$blood_units, 180)
})

test_that("blood labels are the eight US donor types and counts are whole bags", {
  expect_setequal(unique(demo_inventory$blood_type), c("O+", "A+", "B+", "AB+", "O-", "A-", "B-", "AB-"))
  expect_true(all(demo_inventory$blood_units > 0))
  expect_equal(demo_inventory$blood_units, round(demo_inventory$blood_units))
})

test_that("the drawn shares track the cited US distribution", {
  # F02 has 180 bags: the closest any fridge comes to the population mix.
  bt <- bloodtype_table(demo_inventory, "F02")
  expect_equal(sum(bt$share), 1)
  # O+ is the commonest type; AB- the rarest. Both must hold in a fair draw.
  expect_equal(bt$blood_type[1], "O+")
  expect_equal(utils::tail(bt$blood_type, 1), "AB-")
  expect_gt(bt$share[bt$blood_type == "O+"], 0.25)
  expect_lt(bt$share[bt$blood_type == "AB-"], 0.05)
})

test_that("bloodtype_table splits at-risk bags by the fridge's own shares", {
  a <- analyze_all(spike_readings("F02", last_temp = 7.5), demo_inventory)[["F02"]]
  expect_gt(a$units_at_risk, 0) # the fridge is red, so its bags are at risk
  bt <- bloodtype_table(demo_inventory, "F02", a$units_at_risk)
  expect_equal(sum(bt$blood_units), 180)
  expect_equal(sum(bt$units_at_risk), a$units_at_risk)
  # Each type carries the at-risk fraction at its own share of the fridge.
  expect_equal(bt$units_at_risk, bt$blood_units * min(1, a$units_at_risk / 180))
  # The commonest type carries the most at-risk bags.
  expect_equal(bt$blood_type[which.max(bt$units_at_risk)], "O+")
})

test_that("a healthy fridge puts no bags at risk", {
  a <- analyze_all(spike_readings("F02"), demo_inventory)[["F02"]]
  expect_equal(a$units_at_risk, 0)
  bt <- bloodtype_table(demo_inventory, "F02", a$units_at_risk)
  expect_equal(sum(bt$units_at_risk), 0)
  expect_equal(sum(bt$blood_units), 180)
})

test_that("a fridge with no inventory rows returns no rows, not an error", {
  expect_equal(nrow(bloodtype_table(demo_inventory, "F99", 5)), 0)
  expect_equal(nrow(bloodtype_table(NULL, "F02", 5)), 0)
  expect_equal(nrow(bloodtype_table(demo_inventory, NA_character_, 5)), 0)
  empty <- bloodtype_table(demo_inventory, "F99")
  expect_named(empty, c("blood_type", "blood_units", "share", "units_at_risk"))
})

test_that("a zero-bag fridge contributes no rows", {
  inv <- rbind(demo_inventory,
               data.frame(fridge_id = "F07", blood_type = c("O+", "A+"),
                          blood_units = c(0, 0), stringsAsFactors = FALSE))
  expect_equal(nrow(bloodtype_table(inv, "F07")), 0)
  # And it does not disturb the totals of the other fridges.
  expect_equal(sum(bloodtype_table(inv, "F02")$blood_units), 180)
})

test_that("the same type named twice on one sheet is added together", {
  inv <- rbind(demo_inventory,
               data.frame(fridge_id = "F02", blood_type = "O+",
                          blood_units = 5, stringsAsFactors = FALSE))
  bt <- bloodtype_table(inv, "F02")
  expect_equal(sum(bt$blood_units), 185)
  expect_equal(bt$blood_units[bt$blood_type == "O+"], 80)
  expect_equal(nrow(bt), length(unique(bt$blood_type)))
})

test_that("prepare_inventory accepts a totals-only sheet and labels it untyped", {
  old <- prepare_inventory(data.frame(fridge_id = c("F01", "F02"), blood_units = c(12, 180)))
  expect_equal(old$blood_type, c("untyped", "untyped"))
  expect_equal(old$blood_units, c(12, 180))
})

test_that("prepare_inventory keeps the three-column shape and drops bad rows", {
  inv <- prepare_inventory(data.frame(
    fridge_id = c("F01", "F01", "F02", "F03", "F04"),
    blood_type = c("O+", "", "A+", "O-", NA),
    blood_units = c(5, 7, -3, 2, 4)
  ))
  expect_named(inv, c("fridge_id", "blood_type", "blood_units"))
  # blank or missing type becomes untyped; the negative count is the only dropped row
  expect_equal(inv$blood_type, c("O+", "untyped", "O-", "untyped"))
  expect_equal(inv$blood_units, c(5, 7, 2, 4))
})

test_that("prepare_inventory still refuses a file with no bag counts", {
  expect_error(prepare_inventory(data.frame(fridge_id = "F01")), "missing column")
})
