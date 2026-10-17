# ColdChain Monitor demo

These files are synthetic. Seed 5300. The codebook is `data/README.md`.

Start the app from the repo root:

```bash
Rscript app/testme.R
```

Open http://127.0.0.1:5763. The three CSVs load on their own. Stop the app with Ctrl-C.

To see the same numbers without the browser:

```bash
Rscript demo/show_numbers.R
```

The command prints `DEMO OK` and the lines below. If your lines differ, the data or the functions changed.

## readings.csv

Command: `Rscript demo/show_numbers.R`

What you see: six fridges, one row every 15 minutes from 2026-10-01 00:00:00 through 2026-10-07 23:45:00. Limits are frozen from the first 48 hours.

| Fridge | Badge | Bags at risk | Ppk | Cpk | Hours to 1 or 6 °C | Risk priority number | Sentence |
|---|---|---|---|---|---|---|---|
| F02 | red | 180 | 5.864 | 6.151 | already out | 900 | inside the spec width, but not stable |
| F04 | red | 0 | 6.133 | 6.281 | > 72 h | 100 | inside the spec width, but not stable |
| F06 | red | 55 | 6.078 | 5.913 | > 72 h | 54 | inside the spec width, but not stable |
| F03 | red | 40 | 5.583 | 5.813 | > 72 h | 50 | inside the spec width, but not stable |
| F05 | amber | 8 | 5.121 | 4.947 | > 72 h | 18 | inside the spec width, but not stable |
| F01 | amber | 0 | 5.536 | 5.474 | > 72 h | 15 | inside the spec width, but not stable |

How to read this: red means act this shift, amber means watch. F02 is already leaving 6 °C, so it is first. F01 was planted as healthy and is amber because nine hourly means sat on one side of the center. That can happen when readings 15 minutes apart are not independent.

Overview boxes from this file together with the other two: 6 fridges needing action, 283 blood units at risk, average Ppk 5.719.

## inventory.csv

Command: the same `Rscript demo/show_numbers.R`. The bag counts are F01 12, F02 180, F03 40, F04 220, F05 8, F06 55.

What you see: those counts become the severity part of the risk priority number. F04 holds 220 bags, the highest severity, but it ranks second because the blackout is already over.

How to read this: a high bag count raises the rank only together with a live signal. Bags at risk are 283, the sum of the bags in fridges that are out of range now or flagged in the last 24 hours. F04's 220 bags are not in that sum, because its latest temperature is back inside 1–6 °C.

## generator_log.csv

Command: the same script. It prints:

```text
n=30  center=7.550  lower=1.270  upper=13.830  2026-10-06 transfer=48 seconds
```

What you see: 30 daily transfer tests. Ordinary days are a few seconds. 2026-10-06 is 48 seconds, the same afternoon as the F04 blackout. The last transfer on the overview is 48 seconds.

How to read this: the individuals chart center is 7.550 seconds and the upper limit is 13.830 seconds. 48 seconds is far above that limit and above the 10 second spec. A transfer that slow is the one to investigate.
