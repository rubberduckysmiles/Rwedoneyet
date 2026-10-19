# ColdChain Monitor app

Shiny dashboard for the blood-bank operations manager. It ranks refrigerators so a shift can service or evacuate a fridge before red blood cells leave 1–6 °C. The full method, every function argument, and the hand-check numbers are in the repo [README](../README.md). The dataset walk-through is [demo/README.md](../demo/README.md).

Statistics live in `R/`. `qc.R` only sources those files. `app.R` only draws them.

## Run

From the repo root:

```bash
Rscript app/testme.R
```

Open http://127.0.0.1:5763. No arguments. Stop with Ctrl-C.

```bash
Rscript app/workflow.R
```

Prints `WORKFLOW OK` when the ten-hour example matches SPEC.md section 4.

## The four scripts

| Script | What it does |
|---|---|
| `testme.R` | Starts the app on http://127.0.0.1:5763. |
| `workflow.R` | Checks the known-answer numbers, then runs fridge F01 from `data/readings.csv` through `freeze_baseline`. |
| `manifestme.R` | Writes `manifest.json` on this machine. Run `Rscript app/manifestme.R` from the repo root after the app files change. Do not run it in GitHub Actions. |
| `deployme.R` | Publishes this folder to Posit Connect from your machine with `rsconnect`, from the committed `manifest.json`. It reads `CONNECT_SERVER` and `CONNECT_API_KEY` from the environment or the gitignored `.env`, refuses to run without them, and never prints or stores them in the repo. The GitHub Actions workflow stays the main publish path and will overwrite what this publishes. |

## Published app

[ColdChain Monitor on Posit Connect](https://connect.systems-apps.com/content/7da4a137-8c89-44c1-a191-7c9e9317f590/). Content name `rubberduckysmiles-Rwedoneyet-shiny`. The Connect bundle is this folder, so the demo CSVs also live in `app/data/`. Locally, if `data/` exists next to `app/`, the app reads that folder instead.

## Pages

Overview, Fridge Detail, Capability, Backup generator, and Data. Red means act this shift, amber means watch, green means leave it. Limits stay frozen after the first 48 hours, and the Overview page says so.
