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
- The name is on a dark red bar. Each fridge card keeps its border, with a bar in the badge color down the left edge
- Fridges needing action, blood units at risk, average Ppk, last backup generator transfer
- The first three are coloured by their value: green at zero (or, for Ppk, at or above 1) and red otherwise, so a number that needs attention is visible at a glance. Average Ppk stays uncoloured until at least one fridge has usable limits
- Dataset dropdown beside the status line: picking a dataset reloads it at once, and the Data page picker follows. The card says Dataset 2 is ordinary noise and Dataset 1 is the mixed set. The three choices are General demo (planted failures), Dataset 1, and Dataset 2
- "How to read the fridge cards" is collapsed. Open it for the column meanings. The risk priority number is printed on each card as its own product, so the formula is never repeated in a sentence
- Fridge cards: badge, then a 180 px hourly chart on the left with five labelled rows to its right — blood units, Ppk, RPN, mean and standard deviation. The RPN carries its three factors in brackets as the app formats it, so F02 reads "RPN 900 (9 × 10 × 10)"; there is no separate breakdown element under the numbers. Below the rows is that fridge's own special-cause sentence. The forecast is not printed on the card
- Limits frozen from first 48 hours
- Every chart's axis labels, tick numbers, and in-chart notes are drawn in the page's text colour, so they stay readable in both light and dark mode

### 2) Fridge and Generator Detail
- One dropdown: a fridge, or Backup generator. The generator is the whole plant, not a seventh fridge
- A fridge: X-bar, range, and s-charts with baseline shaded; 1–2 SE zone lines shown (not control limits)
- Violations table with hour/chart/test and plain-English meaning
- Blood types present and which are at risk: at-risk bags are always red and within-spec bags always green, whatever the fridge's badge
- Date range picker, for a fridge
- Backup generator: individuals and moving-range charts with the 10 s threshold

### 3) Capability
- The sentence is on a dark red bar. The card keeps its border, and a left edge shows the sentence color: green, amber, red, or gray. The fridge picker sits on the bar
- Cpk, Ppk, and Gap each have one line. The longer reading is a closed dropdown
- Histogram shades 1–6 °C and still marks 1 °C, the 3.5 °C target, and 6 °C. A closed note separates those spec lines from the control limits
- Rolling 24-hour Ppk (96 readings = 24h at 15m) with a dashed line at 1.0. A falling line means worsening
- Backup generator is one row: last transfer, typical transfer, tests beyond the limits
- All six value boxes are coloured by their value, the same way the Overview boxes are: Cpk and Ppk green at or above 1 and red below; Gap green while it stays within 0.10 of zero and red once it does not (judged on distance from zero, not sign, so −0.06 reads green and +0.29 reads red); last and typical transfer green at or below the 10 s line and red above; tests beyond the limits green at zero and red above. A value that cannot be computed yet gets no colour
- 10 s line is team-chosen threshold (not spec or control limit), and is the line the transfer colours use, so this card and the Overview agree

### 4) Data
- Upload readings/inventory/generator log or load demo; see data/README.md and CODEBOOK.md

### 5) Docs
- A centered column. Summary with three facts, and links to the repository, the README, and the dataset codebook
- The Team is open: Hannah Brine, Sue Cho, Tanya Schilling
- Closed sections: How to use (numbered steps), Statistical Methods (the equations), Data (row counts and file links), Tests and Verification, Assumptions and Limitations (a table)

## Quick check
`Rscript demo/show_numbers.R` prints generator: n=30 center=7.550 lower=1.270 upper=13.830; 2026-10-06 transfer=48 seconds; DEMO OK.

## Value
- Early warning via eight SPC tests; time-based forecast drives action
- Bag-level clarity (units at risk, blood-type breakdown) for triage
- Distinguishes "not capable" from "capable but not stable"
- Tracks generator resilience (48 s vs ~7.5 s center) to prevent outages
