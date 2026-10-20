# Bank of Bloody Mary demo

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

The badge has its own measurement, because it is the one number that decides which fridge the manager opens first:

```bash
Rscript demo/alert_rate.R
```

It applies the shipped badge rule and four alternatives — including the rule that shipped before it, kept as `previous` so the change stays measurable — to 200 simulated fridges per population (healthy, drifting and stepped) and to the three committed readings files, then prints `every fridge agrees with the shipped badge` while that copy of the shipped rule still matches `analyze_fridge()`. The numbers behind the rule now in the app are in `data/README.md`.

## readings.csv

Command: `Rscript demo/show_numbers.R`

What you see: six fridges, one row every 15 minutes from 2026-10-01 00:00:00 through 2026-10-07 23:45:00. Limits are frozen from the first 48 hours.

| Fridge | Badge | Bags at risk | Ppk | Cpk | Hours to 1 or 6 °C | Risk priority number | Sentence | Card sentence (this shift) |
|---|---|---|---|---|---|---|---|---|
| F02 | red | 180 | 5.864 | 6.151 | already out | 900 | inside the spec width, but not stable | one point outside the 3-sigma limits |
| F04 | green | 0 | 6.133 | 6.281 | > 72 h | 100 | inside the spec width, but not stable | no special-cause flag |
| F06 | amber | 55 | 6.078 | 5.913 | > 72 h | 54 | inside the spec width, but not stable | one point outside the 3-sigma limits |
| F03 | red | 40 | 5.583 | 5.813 | > 72 h | 50 | inside the spec width, but not stable | nine points in a row on one side of the center |
| F05 | amber | 8 | 5.121 | 4.947 | > 72 h | 18 | inside the spec width, but not stable | nine points in a row on one side of the center |
| F01 | green | 0 | 5.536 | 5.474 | > 72 h | 15 | inside the spec width, but not stable | no special-cause flag |

How to read this: red means act this shift, amber means watch. The last column is the card sentence, and it is deliberately narrower than the sentence beside it: the capability sentence answers "is this fridge stable at all?" (`any_flag_post`, whole chart), while the card sentence answers "what happened in the last day?" (`flag_sentence`, the badge's own 24-hour window). So F04 and F01 are green and read "no special-cause flag" even though both still have old flags keeping their capability sentence at "not stable" — the two sentences describe two different periods, on purpose. F02 is already leaving 6 °C, so it is first. F03 is red for the same reason: its last door-open pair, 7.40 and 6.50 °C on 2026-10-07 at 09:00 and 09:15, is a reading outside 1–6 °C inside the last day. The badge needs a reading out of range, or two test-1 points in a row, inside the last 24 hours, so one isolated hourly mean no longer raises it: F01 was planted as healthy and is green, with its 12 bags counted as not at risk. F06 is amber because its daily 02:00 defrost lifts that hour's mean enough to trip two tests inside the day — worth watching, not an evacuation. F04's blackout is over and more than a day old, so F04 is green too, and because units at risk uses the same 24-hour window, the badge and the bag count agree about it instead of contradicting each other. The measurement behind the rule, and the case the window costs, are in `demo/alert_rate.R` and `data/README.md`.

Overview boxes from this file together with the other two: 4 fridges needing action, 283 blood units at risk, average Ppk 5.719.

## inventory.csv

Command: the same `Rscript demo/show_numbers.R`. The bag counts are F01 12, F02 180, F03 40, F04 220, F05 8, F06 55.

What you see: those counts become the severity part of the risk priority number. F04 holds 220 bags, the highest severity, but it ranks second because the blackout is already over.

How to read this: a high bag count raises the rank only together with a live signal. Bags at risk are 283, the sum of the bags in fridges that are out of range now or flagged in the last 24 hours. F04's 220 bags are not in that sum, because its latest temperature is back inside 1–6 °C.

The file has one row per fridge per blood type, drawn from the US donor frequencies in `data/README.md`. The rows for a fridge add up to its total, so every number above is the same as it was before blood types existed.

The script also prints one line per fridge:

```text
Blood types by fridge (display only: no badge, index or RPN uses them)
  F02  180 bags: O+=75 (at risk), A+=58 (at risk), O-=14 (at risk), B+=11 (at risk), A-=8 (at risk), AB+=8 (at risk), B-=4 (at risk), AB-=2 (at risk)
  F04  220 bags: O+=83, A+=79, B+=19, O-=17, A-=11, AB+=6, AB-=3, B-=2
  F06  55 bags: A+=20 (at risk), O+=17 (at risk), B+=7 (at risk), O-=5 (at risk), AB+=3 (at risk), A-=2 (at risk), AB-=1 (at risk)
  F03  40 bags: O+=15 (at risk), A+=12 (at risk), B-=3 (at risk), O-=3 (at risk), AB+=2 (at risk), AB-=2 (at risk), B+=2 (at risk), A-=1 (at risk)
  F05  8 bags: A+=3 (at risk), AB+=2 (at risk), AB-=1 (at risk), B+=1 (at risk), O+=1 (at risk)
  F01  12 bags: O+=6, A+=4, A-=1, O-=1
```

How to read this: "(at risk)" appears only for fridges whose bags are in the units-at-risk total, 283. F02 is already out of range, so all 180 of its bags are marked. F04 is green and back inside 1–6 °C, so none of its 220 are. F01 is green with no live signal, so none of its 12 are. Open Fridge Detail in the app to see the same breakdown as a chart, with the at-risk bags in the badge color.

## generator_log.csv

Command: the same script. It prints:

```text
n=30  center=7.550  lower=1.270  upper=13.830  2026-10-06 transfer=48 seconds
```

What you see: 30 daily transfer tests. Ordinary days are a few seconds. 2026-10-06 is 48 seconds, the same afternoon as the F04 blackout. The last transfer on the overview is 48 seconds.

How to read this: the individuals chart center is 7.550 seconds and the upper limit is 13.830 seconds. 48 seconds is far above that limit and above the 10 second spec. A transfer that slow is the one to investigate.
