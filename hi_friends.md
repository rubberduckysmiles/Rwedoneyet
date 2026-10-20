# Hi friends!

This is the handoff for Bank of Bloody Mary.
H-01 through H-29 are done and pushed to [github.com/rubberduckysmiles/Rwedoneyet](https://github.com/rubberduckysmiles/Rwedoneyet). **H-08 is the only task left**, and it is a person, not a commit: it submits the repo on Devpost. Please do not mark anything done until the checks below are actually run.

The live app, with no login, is [Bank of Bloody Mary on Posit Connect](https://connect.systems-apps.com/content/7da4a137-8c89-44c1-a191-7c9e9317f590/). A logged-out request returned HTTP 200 and the page title Bank of Bloody Mary. Access on Connect is set so anyone can open it. Leave it that way. Judges have to open it without an account.

Virtual DL deadline is Friday, October 23, 2026, 3:00 PM ET. The prompt is Blood Banks. The user is the blood-bank operations manager who decides, each shift, which fridge to service or evacuate before red blood cells leave 1–6 °C.

## Read these first

Read them in this order. The later files assume the earlier ones.

1. [SPEC.md](SPEC.md), section 4. This is the method and the hand-check numbers. Every teammate should be able to say that paragraph without reading it. If the app and SPEC disagree, SPEC wins and the code is the bug.
2. [docs/plan.md](docs/plan.md). The formulas, the badge rules, and the risk-priority scores. These were decided on purpose. Do not quietly change the 1.0 capability cutoff, the bag bands, or the occurrence scores.
3. [README.md](README.md). What the tool is, every input, every function argument, how to run it, and the live URL.
4. [demo/README.md](demo/README.md). The six fridges and the numbers the demo prints. If you cannot explain a number on that page, it is not ready to show a judge.
5. [data/README.md](data/README.md). The codebook. All of `data/` is synthetic, seed 5300. Say that out loud if someone asks where the data came from.
6. [CONTRACT.yaml](CONTRACT.yaml). The task ledger. One task at a time. Open: H-08 only.

## What is already built

| Task | What exists |
|---|---|
| H-01 | SPEC.md is filled in. No `FILL IN` blanks left. |
| H-02 | `readings.csv`, `inventory.csv`, `generator_log.csv`, and the codebook. Six fridges, one reading every 15 minutes, 2026-10-01 through 2026-10-07. |
| H-03 | The statistics, in plain R under `app/R/`. `app/qc.R` only sources those files. The suite now prints `FAIL 0 \| WARN 0 \| SKIP 0 \| PASS 1068`. |
| H-04 | The Shiny app in `app/app.R`. Pages: Overview, Fridge Detail, Capability, Backup generator, Data. |
| H-05 | `demo/show_numbers.R` and the demo walk-through. It prints `DEMO OK`. |
| H-06 | GitHub Actions deploys `app/` to the course Posit Connect server. The publisher key is only in GitHub Actions secrets. |
| H-07 | The root README and `app/README.md`. |
| H-09 | `inventory.csv` is one row per fridge per blood type, and Fridge Detail shows the breakdown. Display only: it moves no published number. |
| H-10 | The standard-deviation chart on Fridge Detail, with `c4`, `B5` and `B6` computed rather than looked up. Display only. |
| H-11, H-12 | README section 7 and the on-screen captions: what every number means and why it is the one we chose. |
| H-13 | CODEBOOK.md: every file, every function, every computed variable, and the chosen-versus-computed split. |
| H-14 | The user and use case stated one way everywhere: the blood-bank operations manager, at shift change. |
| H-15 | The generator statistics strip and plain captions on the Capability tab. |
| H-16, H-17, H-18 | Hygiene and accuracy: the stray `README copy.md` is gone, the Switchover caption now agrees with the Switchover value, and the two scenario datasets are described from measurement. |
| H-22 | The two scenario readings sets are back to the team's hand-tuned versions (the names are labels, not descriptions: the bad set has nothing failing, and the good set has no textbook failure), and `data/README.md` describes both from measurement. `make_scenarios.R` now writes its own generated pair into `data/scenario_generated/` and cannot overwrite the committed sets. |
| H-24 | Dead code out: `ordinal()`, `sparkline_plot()` and `READINGS_COLUMNS` are gone. |
| H-25 | `tests/test-scenarios.R` pins both scenario sets by md5 and by their measured verdicts, and `data/README.md` states what the first badge rule did to a healthy fleet. |
| H-26 | `demo/alert_rate.R` measures the badge under five aggregation rules on 200 simulated fridges per population: healthy, drifting and stepped. |
| H-27 | The product is named Bank of Bloody Mary in every document and every file header. |
| H-28 | The badge rule changed because of that measurement: two flags inside the last 24 hours, not one. `demo/alert_rate.R` still measures the old rule as `previous`, so the change stays visible. |
| H-29 | `Demo.md` is UTF-8, and `demo/README.md` points at the alert-rate script. |
| H-32 | The card sentence reads the same 24 hours the badge judges, so a green card cannot announce an old shift and an amber card says which pattern made it amber. `tests/test-flag_sentence.R` pins the three cards that exposed it. No verdict moved. |

The known-answer check is ten hours of temperatures whose hour means are all exactly 3.5 °C. Sigma short is 0.2569046516. Cpk is 3.2437456007. Ppk is 3.6984390192. The gap is negative on that set because the hour means do not move. Constant data, every reading 3.5 °C, makes Cpk and Ppk missing. They are never infinity. `Rscript app/workflow.R` prints `WORKFLOW OK` when this still matches.

On the demo data the overview is: 4 fridges needing action, 283 blood units at risk, average Ppk 5.719, last backup generator transfer 48 seconds. The fridge table, including why F02 is red on a live out-of-range reading, why F06 is amber for its daily defrost and why F04 is green after its blackout aged out of the 24-hour window, is in [demo/README.md](demo/README.md).

## Please review these before changing anything

**The demo data was restored on 2026-10-20.** Commit `654f766` ("fixing data") overwrote `data/readings.csv` with a copy of `data/scenario_one_good/readings.csv` and left `app/data/` alone, which put the suite at `FAIL 62` and made the repo and the shipped app disagree about all six fridges — F02's drift and F04's blackout vanished from the demo. `data/readings.csv` is back to the hand-tuned file, byte-identical to `app/data/readings.csv` as it was before that commit, and the suite is green again. `docs/FINDING-data-readings-overwrite.md` has the evidence. If you meant to change the demo, change `data/` and `app/data/` together.

The statistics are the graded part. Read the function, then the test next to it.

- `app/R/` holds one file per piece: subgroups and the two sigmas, `d2` and `d3`, control limits, the frozen baseline, the eight special-cause tests, the forecast, the risk scores, and the generator individuals chart. `tests/` has the matching tests. The ten-hour rows live in `tests/known_rows.R`, not in a fourth CSV.
- `d2` and `d3` are computed with `ptukey` and `integrate`. Do not replace them with a table, and do not switch sigma short over to a range-chart constant. The generator chart is the one place that uses mean moving range divided by `d2`, and that is only because it is an individuals chart.
- Do not call the eight tests by a person's name anywhere in the app, the tests, or the README. The functions are `special_cause_test_1` through `special_cause_test_8`. A point exactly on a line is not a flag.
- No costs anywhere. The risk number is severity times occurrence times urgency. Urgency is hours until 1 °C or 6 °C. It replaces the usual detection score, and [docs/plan.md](docs/plan.md) says so.
- Limits freeze after the first 48 hours. Later data must not move them. The Overview page says this. Lag-1 autocorrelation is printed as a limitation and is not used to widen the limits.

Two demo results used to look surprising. H-28 answered them by measuring the aggregation, not by explaining it away: the eight tests are right and the badge rule was wrong.

- F01 was planted as healthy and came out amber, because test 2 fired on nine hourly means sitting on one side of the center. With about 120 post-baseline hours and eight tests, a healthy fridge nearly always trips something somewhere — and dependence is not the reason: measured lag-1 is 0.02 on F01, under 0.16 everywhere. The badge now asks for two flags inside the last 24 hours, so F01 is green and its 12 bags are not in the at-risk count.
- F06 is the healthy fridge with a normal defrost. Its defrost lifts one hour a day enough to trip two tests inside the last day, so it is amber — worth watching — and its 55 bags are in the 283 units at risk.

F02 is the one to talk about first. The compressor drifts, it is already above 6 °C, it holds 180 bags, and its risk priority number is 900.

## How to run it

From the repo root:

```bash
Rscript app/testme.R
```

Open http://127.0.0.1:5763. Stop it with Ctrl-C. Needs R with `shiny`, `bslib`, `plotly`, `DT`, and `testthat`. This copy was built on R 4.5.2.

```bash
Rscript app/workflow.R
Rscript demo/show_numbers.R
Rscript -e 'testthat::test_dir("tests")'
```

If you regenerate the CSVs with `Rscript data/make_data.R`, copy the three files into `app/data/` as well. The published app only receives the `app/` folder. Then run `Rscript app/manifestme.R` on your own machine and commit the new `manifest.json`. Do not let GitHub Actions rewrite the manifest.

The two scenario sets under `data/scenario_one_bad/` and `data/scenario_one_good/` are the team's hand-tuned versions, restored by H-22, and are described in [data/README.md](data/README.md) with their measured numbers. They do **not** come from `Rscript data/make_scenarios.R`; that script writes a different pair of sets into `data/scenario_generated/` (not committed) and never overwrites these two. The scenario sets are **not** used by the app, so they do not go into `app/data/` and they do not change the manifest.

## What is left

H-08 is the only open task; every other task in the ledger is `done`. H-08 owns `.gitignore` only. Its check is: clone the public repo into an empty folder, run `Rscript app/testme.R` and the tests with no extra steps, confirm `git grep -i "api_key"` finds no real key, and submit the repo on Devpost. The repo is already public. The Devpost submission is a person, not a commit, so no code change closes it. The live URL to paste there is the Connect link at the top of this note. The deadline is the Virtual DL track's, Friday, October 23, 2026, 3:00 PM ET.

Do not put the Connect publisher key, or any other secret, in a file, a commit, or the chat. It stays in the GitHub Actions secrets named `CONNECT_SERVER` and `CONNECT_API_KEY`.
