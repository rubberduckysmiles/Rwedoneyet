# Codebook for `data/`

**All data in this folder are synthetic.** They were invented, not measured on any real
refrigerator, bag of blood, or generator. Seed 5300 (blood types, 5301). Regenerate the three CSVs at
the top level, byte for byte, from the repo root with:

```
Rscript data/make_data.R
```

`data/make_data.R` is the generator for `readings.csv`, `inventory.csv` and `generator_log.csv`, and
those three are its output. Do not edit them by hand.

The two scenario folders are the exception. Their `readings.csv` files came from a hand-tuned pass,
are not reproducible from any script here, and are described, with their measured numbers, under
[The two scenario sets](#the-two-scenario-sets) below. `data/make_scenarios.R` generates a *different*
pair of sets into `data/scenario_generated/` (not committed) and never overwrites the two folders.

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
| `make_scenarios.R` | n/a | Generates a pair of alternative readings sets into `data/scenario_generated/`, which is not committed. It does not write the two folders below. |
| `scenario_one_bad/` | folder | Committed set: `readings.csv` plus copies of `inventory.csv` and `generator_log.csv`. All six fridges are common-cause noise; nothing fails in this file. |
| `scenario_one_good/` | folder | Committed set: `readings.csv` plus copies of the other two files. Every fridge behaves differently: one near 1.5 °C, one warm near 5 °C, one with half the usual spread, and door/generator flags that never move the temperature. |

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

## The two scenario sets

`data/scenario_one_bad/readings.csv` and `data/scenario_one_good/readings.csv` are committed
alternatives to `readings.csv`: same six fridges, same 672 readings each, same columns, same
2026-10-01 to 2026-10-07 window. Each folder also holds a copy of `inventory.csv` and
`generator_log.csv`, unchanged from `data/`, so a fridge's bag count and the backup-power log are the
same whichever readings file is in use.

**The running dashboard does not load these.** The app reads `data/readings.csv` (or its own copy in
`app/data/`); nothing under `app/` mentions a scenario folder. They are alternative readings sets for
working the statistics by hand.

**Where they came from.** These two files are the team's hand-tuned pass from the `data-updates`
branch (commits `08641c9` for the bad set, `68a6804` for the good set), and they are the versions the
team chose to keep. They are **not** reproducible from any script in this repo. `data/make_scenarios.R`
builds a *different* pair of sets — one drifting fridge, and five fridges with drift used twice — and
writes them into `data/scenario_generated/`, a folder that is not committed, so running that script
cannot overwrite the two files described here. The tables below are measured from the committed files,
not derived from a script.

Treat the names as labels, not descriptions. The point of both sets is that a range check (1 to 6 °C)
and a control chart disagree about which fridge needs attention.

### `scenario_one_bad/readings.csv`

Despite the name, nothing fails in this file. All six fridges show common-cause noise only: normal,
mean about 3.5 °C, standard deviation about 0.15 °C, rounded to 2 decimals, no door or generator
flags. It is the negative control for the other two readings files: a monitor that finds something
here is finding a false alarm.

| Fridge | Mean | SD | Min | Max | Readings outside 1–6 °C | Door / generator flags |
|---|---|---|---|---|---|---|
| F01 | 3.49 | 0.152 | 3.09 | 3.91 | 0 | 0 / 0 |
| F02 | 3.50 | 0.148 | 3.09 | 3.91 | 0 | 0 / 0 |
| F03 | 3.51 | 0.155 | 3.09 | 3.91 | 0 | 0 / 0 |
| F04 | 3.51 | 0.149 | 3.09 | 3.91 | 0 | 0 / 0 |
| F05 | 3.50 | 0.145 | 3.10 | 3.91 | 0 | 0 / 0 |
| F06 | 3.50 | 0.155 | 3.09 | 3.91 | 0 | 0 / 0 |

### `scenario_one_good/readings.csv`

Also a misleading name: this is not a set of textbook failures but a set of awkward fridges, which is
the harder test. Every fridge behaves differently, and only one of them ever leaves 1–6 °C.

| Fridge | What it does | Mean | SD | Min | Max | Readings outside 1–6 °C | Door / generator flags |
|---|---|---|---|---|---|---|---|
| F01 | Runs with about half the standard spread | 3.50 | 0.075 | 3.15 | 3.84 | 0 | 0 / 0 |
| F02 | Sits near the 1 °C lower limit all week | 1.50 | 0.313 | 1.00 | 2.00 | 0 — 618 of 672 readings are under 2 °C, none is under 1 °C | 0 / 0 |
| F03 | Door openings logged, temperature never responds | 3.55 | 0.169 | 3.08 | 4.00 | 0 | 8 / 0 |
| F04 | Blackout logged, temperature never responds | 3.53 | 0.129 | 3.18 | 3.88 | 0 | 0 / 5 |
| F05 | Very tight, neither stuck flat nor drifting | 3.50 | 0.066 | 3.32 | 3.68 | 0 | 0 / 0 |
| F06 | Runs warm, widest spread of the six | 4.99 | 0.556 | 3.51 | 6.40 | 16 readings above 6 °C, 2026-10-01 09:30 through 2026-10-07 10:30 | 0 / 0 |

Three things are deliberate. **F02** hugs the lower limit for the whole week: no reading is out of
range, so a range check sees nothing, and only a chart of the level finds a fridge running 2 °C below
the others. **F03 and F04** carry door and generator flags in `door_open` and `on_generator` while the
temperature never responds, so the only evidence is the operator's log, not the readings. **F05** has
less than half everyone else's spread — the opposite of a widening chart, and what a settling sensor
looks like. **F06** is the only fridge whose readings leave 1–6 °C, and it does so intermittently
rather than by drifting away.

### What the monitor says about each set (measured)

The tables above describe the files. This one is what the app makes of them: the two
committed files run through the dashboard's own path (`load_demo_data()` then
`analyze_all()`, plus `overview_summary()`). `tests/test-scenarios.R` asserts every
number here, so a change to either file or to the statistics moves this table.

| Set | Red | Amber | Green | Needing action | Bags reported at risk | Average Ppk |
|---|---|---|---|---|---|---|
| `scenario_one_bad` | none | F04, F06 | F01, F02, F03, F05 | 2 of 6 | 275 (F04 220, F06 55) | 5.42 |
| `scenario_one_good` | F06 | F02 | F01, F03, F04, F05 | 2 of 6 | 67 (F06 55, F01 12) | 5.73 |

Two rows are the point of the pair, and both come out as intended. On the good set,
**F02** has no reading outside 1–6 °C and still has a Cpk of 0.537: the level is wrong
while the range is fine, so the range check misses it and the chart does not. **F06** is
the one fridge the range check does catch — 16 readings above 6 °C, 11 of them after the
baseline — with a Cpk of 0.598.

The third is the aggregation, and it is a decision rather than a formula. The bad set has
**nothing outside 1–6 °C**, and under the first badge rule the monitor still reported **5 of
its 6 fridges as needing action**. Dependence is not the cause: roughly 120 post-baseline
subgroups read against 8 special-cause tests means a healthy fridge is almost sure to trip
something somewhere, and that rule turned the badge amber on *any* single post-baseline flag.
Lag-1 autocorrelation is under 0.16 on every fridge, about 0.02 on F01 of the demo file.
Simulating 200 healthy iid-normal fridges (mean 3.5 °C, sd 0.15 °C, 672 readings each)
through `analyze_fridge()` gave **92.0% red or amber** under that rule (64.5% amber,
27.5% red).

H-28 changed the aggregation and left the eight tests alone. The badge now uses the same
24-hour window the bag count uses: red needs a reading outside 1–6 °C or two X-bar test-1
points in a row inside it, and amber needs two flags inside it (Cpk below 1.0 and a crossing
within 12 hours still count, so a slow problem stays visible). Re-measured the same way, and
printed with its alternatives by `demo/alert_rate.R`:

| Badge rule | Healthy fleet red or amber | Real drift red | Flags per healthy fridge |
|---|---|---|---|
| the first rule (any single flag) | 92.0% | 100% | 4.13 |
| the shipped rule (two flags in the last day) | 15.5% | 100% | 4.13 |

A real fault is not lost by asking for two flags: 200 simulated fridges whose ramp reaches
6.5 °C, and 200 that step to 5.0 °C, are **100% red** under the shipped rule. The flag rate
is unchanged, because the eight tests are implemented correctly one by one and the fix is in
the aggregation, not in muting them. `tests/test-scenarios.R` holds both halves of that: a
healthy fleet must mostly come back green, and a drifting fridge must come back red on every
draw.

The cost of the window is recorded rather than hidden. A fault that resolved more than a day
ago drops off the badge. In the demo file F04's blackout ran 2026-10-06 14:00 to 16:00, so
the shipped rule calls F04 green where the first rule said red. `units_at_risk` uses the same
24-hour window, so the badge and the bag count agree — F04's 220 bags are not in the 283. A
two-day window would keep F04 on the list, but would put 38.5% of a healthy fleet at red or
amber instead of 15.5%.

### Checksums

Line endings normalised to LF, which is what `git` stores:

| File | MD5 |
|---|---|
| `data/scenario_one_bad/readings.csv` | `a6ade73760933721328b87202e00c8a6` |
| `data/scenario_one_good/readings.csv` | `2617a7f5de9679533f8d5890d0a4fb12` |

For contrast, the pair `data/make_scenarios.R` writes into `data/scenario_generated/` hashes to
`0696b9ea91c2eedae93d65af736578f2` and `edf520a1bed60149845cc47dd55cded`. Different files — and a
quick way to confirm the generator never touches the committed sets.

## Collecting this for real

- **Temperatures and flags:** a data logger with a probe, a door contact and a power-monitor input
  on each fridge, exporting one row every 15 minutes.
- **Bag counts:** the nurse or technician counts bags per fridge at shift change and types the numbers
  into one sheet.
- **Generator transfer time:** a person with a stopwatch at the scheduled transfer test.

These files are invented to show one behaviour per fridge. They are not real measurements.
