# Demo: Using Bank of Bloody Mary

## Value for the blood bank

Bank of Bloody Mary helps blood-bank operations managers act at shift change to decide which refrigerator to service, evacuate, or leave alone before the next shift, so red blood cells stay within 1–6 °C. It ranks fridges by RPN (severity × occurrence × urgency), highlights action items, shows bags at risk, explains Cpk, Ppk, and gap, and tracks backup generator transfer times.

Control limits (what the fridge does, center ± 3 SE) are kept separate from spec limits (1–6 °C, what red cells need).

## Getting started

```bash
Rscript app/testme.R
```
Open http://127.0.0.1:5763. Demo data loads automatically. Stop with Ctrl-C.

```bash
Rscript demo/show_numbers.R
Rscript app/workflow.R
```

## Walkthrough

### 1) Overview
- Fridges needing action, blood units at risk, average Ppk, last backup generator transfer
- Fridge cards sorted by RPN: badge, blood units, Ppk, "Out of spec in" (forecast), RPN breakdown, plain explanation
- Limits frozen from first 48 hours

### 2) Fridge Detail
- X-bar, range, and s-charts with baseline shaded; 1–2 SE zone lines shown (not control limits)
- Violations table with hour/chart/test and plain-English meaning
- Blood types present and which are at risk
- Date range picker

### 3) Capability
- Cpk, Ppk, Gap with plain captions; histogram (1 °C, 3.5 °C target, 6 °C) noting spec vs control limits
- Rolling 24-hour Ppk (96 readings = 24h at 15m); falling line means worsening
- Backup generator stats (last/typical, beyond limits, switchover) — transfer time is seconds from power loss to load
- 10 s line is team-chosen threshold (not spec or control limit)

### 4) Backup generator
- Individuals and moving-range charts with 10 s threshold; investigate if recent tests fall well above limits

### 5) Data
- Upload readings/inventory/generator log or load demo; see data/README.md and CODEBOOK.md

## Quick check
`Rscript demo/show_numbers.R` prints generator: n=30 center=7.550 lower=1.270 upper=13.830; 2026-10-06 transfer=48 seconds; DEMO OK.

## Value
- Early warning via eight SPC tests; time-based forecast drives action
- Bag-level clarity (units at risk, blood-type breakdown) for triage
- Distinguishes "not capable" from "capable but not stable"
- Tracks generator resilience (48 s vs ~7.5 s center) to prevent outages
