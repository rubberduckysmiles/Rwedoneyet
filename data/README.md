# Codebook for `data/`

**All data in this folder are synthetic.** They were invented by a script, not measured on any real
refrigerator, bag of blood, or generator. Seed 5300 (blood types, 5301). Regenerate every CSV, byte for
byte, from the repo root with:

```
Rscript data/make_data.R
```

`data/make_data.R` is the only generator; the CSVs are its output. Do not edit the CSVs by hand.

**Baseline window (quotable):** The baseline is the first 48 hours, 2026-10-01 00:00:00 through
2026-10-02 23:45:00, in which every fridge has common-cause variation only (no planted failure), and the
control limits are frozen from it.

Safe storage range for red blood cells: **1 to 6 °C**.

## Files

| File | Rows | What it is |
|---|---|---|
| `make_data.R` | n/a | The generator script (R, `set.seed(5300)`, blood types `set.seed(5301)`). |
| `readings.csv` | 4032 (6 fridges x 672) + 1 header | One temperature reading every 15 minutes per fridge, 2026-10-01 00:00:00 through 2026-10-07 23:45:00. |
| `inventory.csv` | 40 + 1 header | How many red-cell bags are in each fridge, one row per fridge per blood type. |
| `generator_log.csv` | 30 + 1 header | One backup-generator transfer test per day, 2026-09-07 through 2026-10-06. |

## `readings.csv`

Columns, in this order. Rows are grouped by fridge (F01 first), in time order. Timestamps are plain
clock time with no time zone.

| Column | Unit | Allowed values | How a technician would record it for real |
|---|---|---|---|
| `fridge_id` | label | `F01`, `F02`, `F03`, `F04`, `F05`, `F06` | The asset tag on the fridge, set once when its logger is installed. |
| `timestamp` | date and time, `YYYY-MM-DD HH:MM:SS` | Every 15 minutes, `2026-10-01 00:00:00` to `2026-10-07 23:45:00`, 672 per fridge | The logger stamps it automatically at each reading. |
| `temp_c` | degrees Celsius (°C) | Number with 2 decimals, for example `3.50`. In this file 2.94 to 7.87. | A probe in a glycerol bottle inside the blood fridge, read by the data logger every 15 minutes and rounded to 0.01 °C. |
| `door_open` | flag | `1` = door open, `0` = door shut | A door-contact switch on the fridge, logged with each reading. |
| `on_generator` | flag | `1` = running on generator power, `0` = on mains | A transfer-switch or power-monitor contact, logged with each reading. |

## `inventory.csv`

One row per fridge **per blood type held**: a fridge with bags of three types has three rows. The rows
for one fridge add up to that fridge's total, and those totals are unchanged from the first version of
this dataset (F01 = 12, F02 = 180, F03 = 40, F04 = 220, F05 = 8, F06 = 55), so every risk priority
number, badge and bag-at-risk figure computed from them is the same either way.

| Column | Unit | Allowed values | How a technician would record it for real |
|---|---|---|---|
| `fridge_id` | label | `F01` to `F06` | Same asset tag as in `readings.csv`. |
| `blood_type` | ABO group plus Rh factor | `O+`, `A+`, `B+`, `AB+`, `O-`, `A-`, `B-`, `AB-` | Printed on the bag label and on the blood bank's inventory sheet, one line per group in the fridge. |
| `blood_units` | count of red-cell bags of that type | Whole number, 1 or more. Types with no bags on the shelf get no row. | Counted by hand from the shift inventory sheet, bags physically in that fridge at the start of the shift. |

**How the types were drawn.** The fridge totals are fixed, and each total is split across the eight
types with `rmultinom()`, using the widely reported US red-cell antigen (ABO/Rh) frequencies:
O+ 38%, A+ 32%, B+ 9%, O- 7%, A- 6%, AB+ 3%, B- 2%, AB- 1%. Those percentages sum to 98, not 100: the
remainder is rare subtypes this eight-type table does not name. `rmultinom()` renormalizes, so the
missing 2% is spread across the eight by weight. The draws use their own seed, 5301, and run after
every other draw in `make_data.R`, so `readings.csv` and `generator_log.csv` stay byte for byte
identical to the version without blood types.

The distribution is the population-level donor figure, cited for the US donor base (AABB / NIH NHLBI
tables as commonly reported). It is a synthetic draw against those probabilities, not a real blood
bank's stock: a real fridge would be skewed by whatever the hospital was given that week.

Blood type is **display only** in this tool. It does not enter the capability indices, the control
limits, the severity score, or the risk priority number. Its one risk-related use is showing which
bags inside an at-risk fridge are of each type, split by that type's own share of the fridge.

## `generator_log.csv`

| Column | Unit | Allowed values | How a technician would record it for real |
|---|---|---|---|
| `date` | date, `YYYY-MM-DD` | One per day, `2026-09-07` to `2026-10-06`, 30 rows | The date written on the transfer-test sheet. |
| `transfer_time_sec` | seconds (s), 1 decimal | Positive number. Ordinary days are 3 to 9 s. One day is 48.0 s. | Stopwatch: start it when mains power is cut in the test, stop it when the generator carries the load. Write the time to 0.1 s. |

The row for `2026-10-06` is `48.0` seconds. That is the F04 blackout below. Every other day is an
ordinary test (drawn around 6 s, kept inside 3 to 9 s).

## The six fridges (what was planted)

Every fridge uses the same common-cause noise underneath: normal, mean 3.5 °C, standard deviation
0.15 °C, rounded to 2 decimals. Nothing is planted before 2026-10-03 00:00:00, except F06's daily defrost,
which is part of its normal routine and runs on every day including the baseline.

| ID | Scenario | What was planted | Clock times |
|---|---|---|---|
| F01 | Healthy | Common-cause noise only. `door_open` = 0, `on_generator` = 0. Stays well inside 1 to 6 °C. | Whole week |
| F02 | Drifting compressor | The mean rises 0.035 °C per hour, counted from 2026-10-03 00:00:00. At 72 hours the mean is about 6.0 °C, so the readings are above 6 °C by 2026-10-07. This is wear: not a door, not a power cut. | From 2026-10-03 00:00:00 to the end |
| F03 | Door-open spikes | Eight readings (four pairs) have `door_open` = 1 and a fixed temperature, not noise plus a spike: 7.50 and 6.80 °C on 10-04 at 08:00 and 08:15; 7.20 and 6.40 on 10-05 at 12:00 and 12:15; 7.80 and 6.60 on 10-06 at 18:00 and 18:15; 7.40 and 6.50 on 10-07 at 09:00 and 09:15. The last pair is inside the last 24 hours of the file. | 2026-10-04 08:00 to 2026-10-07 09:15 |
| F04 | Blackout, slow generator | On 2026-10-06 the mains are lost at 14:00 and the generator is slow. Nine fixed readings: 4.80, 5.60, 6.50 (generator 0), then 7.40, 6.80, 5.70, 4.80, 4.10 (generator 1), then 3.70 (generator 0). Matches the 48.0 s row in `generator_log.csv`. | 2026-10-06 14:00 to 16:00 |
| F05 | Flatlined sensor | `temp_c` is exactly 3.50 on every reading (144 readings). The stuck value is inside 1 to 6 °C on purpose: a range check alone would not catch it. | 2026-10-04 00:00 to 2026-10-05 11:45 |
| F06 | Healthy, normal defrost | Common-cause noise, plus one scheduled defrost a day: the single 02:00:00 reading is the noise draw + 0.40 °C. The other three readings in that hour are ordinary, so the hourly mean rises about 0.10 °C. A manager can see it and still treat the fridge as healthy. | 02:00:00 every day, 2026-10-01 to 2026-10-07 |

## Collecting this for real

- **Temperatures and flags:** a data logger with a probe, a door contact and a power-monitor input
  on each fridge, exporting one row every 15 minutes.
- **Bag counts:** the nurse or technician counts bags per fridge at shift change and types the numbers
  into one sheet.
- **Generator transfer time:** a person with a stopwatch at the scheduled transfer test.

These files are invented to show one behaviour per fridge. They are not real measurements.
