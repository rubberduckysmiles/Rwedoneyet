# Plan: ColdChain Monitor

User: the blood-bank operations manager. Question: which fridge to service or evacuate this shift, before red cells leave 1–6 °C. Target 3.5 °C is the middle of the spec. It is not the control-chart center.

## Formulas
A subgroup is the 4 readings in one hour. Variance divides by n − 1. σ_short = √(mean of the baseline subgroup variances). σ_overall = sample sd of every baseline reading. X-bar center = grand mean. Limits and zones = center ± k σ_short/√n for k = 1, 2, 3. d2 and d3 are the mean and sd of the range of n standard normals, from `ptukey` with infinite degrees of freedom. Range center = d2 σ_short. Range upper = (d2 + 3 d3) σ_short. Range lower = max(0, (d2 − 3 d3) σ_short). Cpk = min(6 − mean, mean − 1) / (3 σ_short). Ppk uses σ_overall in that denominator. Gap = Cpk − Ppk. Baseline = the first 48 hours and at least 25 subgroups. Later hours use those frozen limits. Lag-1 is the correlation of each baseline reading with the reading 15 minutes later. Forecast: a straight line on subgroup means after hour 48, then hours until the line hits 1 °C or 6 °C. Rolling Ppk uses the trailing 24 hours. RPN = Severity × Occurrence × Urgency, each scored 1–10. Generator transfer times use an individuals and moving-range chart. There σ_short = (mean moving range) / d2, with d2 computed at n = 2. Upper spec = 10 seconds. Tests `special_cause_test_1` through `_8` run on X-bar. Test 1 also runs on the range chart. A point exactly on a line is not a flag.

## Known answer
Stable 10 hours in SPEC section 4. σ_short = 0.2569046516. σ_overall = 0.2253202849. X-bar limits 3.8853569774 and 3.1146430226. Range center 0.5289026431, upper 1.2069831025, lower 0. Cpk 3.2437456007. Ppk 3.6984390192. Gap −0.4546934185. Lag-1 −0.2174115934. Drift check in SPEC: gap +1.1453802560. n = 4 gives d2 = 2.0587507460 and d3 = 0.8798082028. n = 5 gives d2 = 2.3259289473 and d3 = 0.8640819411. Constant 3.5 °C: Cpk and Ppk are NA with a message, never Inf or 0.

## Tasks
1. H-01, owns SPEC.md. Prove with `grep -c "FILL IN[.,]" SPEC.md` printing 0. 0.5 h. The team can say the method sentence.
2. H-02, owns data/. Exactly three CSVs: readings, inventory, generator_log, plus data/README.md with units and how a tech would log them. Six planted fridges inside readings.csv. 3 h.
3. H-03, owns app/qc.R and tests/. Write the tests with the SPEC numbers first. One test file per statistic, including the eight rule functions and a constant-data case. Plain R only. 6 h. app/R/ is not in the owns list. Add it to H-03 before coding, because those functions must stay out of the Shiny files.
4. H-04, owns app/. Copy demos/shinyapp into app/. testme on the known-answer rows returns the same numbers. No styling until that matches. 6 h.
5. H-05, owns demo/ and app/frontend/. demo/README.md walks each data CSV: the command, the numbers, and one line on how to read them. 2 h.
6. H-06, owns .github/workflows/, .github/scripts/, app/manifest.json, app/.python-version. Live URL returns the known-answer numbers. The key stays in GitHub secrets. 3 h.
7. H-07, owns README.md and app/README.md. A fresh clone follows it. 2 h.
8. H-08, owns .gitignore. Repo is already github.com/rubberduckysmiles/Rwedoneyet. Submit that link on Devpost. 1 h.

## Decisions
Team Keep It Cool. Virtual DL, due Fri Oct 23, 3 PM ET. Prompt: Blood Banks. Repo: github.com/rubberduckysmiles/Rwedoneyet. Stack: Shiny from demos/shinyapp.
Capable: Cpk ≥ 1.0 and no flag means "capable and stable". Cpk ≥ 1.0 with a flag means "inside the spec width, but not stable". Cpk < 1.0 means "not capable".
Units at risk = bags in fridges outside 1–6 °C now, or with any flag in the last 24 h. Needing action = red or amber. Red: out of spec in the last 24 h, or X-bar test 1. Amber: any other flag, Cpk < 1.0, or a crossing within 12 h. Green: otherwise.
Forecast uses post-baseline hours only. Severity by bags: 1 if 0; then 2 through 10 for 1–5, 6–15, 16–30, 31–50, 51–75, 76–100, 101–150, 151–200, 201+. Occurrence, worst signal: 1 none; 2 test 6; 3 test 5 or 8; 4 test 4; 5 test 2; 6 test 7; 7 test 3; 8 range test 1; 9 X-bar test 1 while inside spec; 10 any reading outside 1–6 °C. Urgency: 10 if already out or within 2 h; then 9, 8, 7, 6, 5, 4, 3, 2, 1 for within 4, 8, 12, 18, 24, 36, 48, 72 h, and more than 72 h or no crossing. Minutes out of spec are shown and are not in the RPN. No dollars. qcc is a cross-check only.

## Risks
1. A packaged chart will not match, because sigma short is the pooled variance, not a range constant. The SPEC numbers are the answer key.
2. Readings 15 minutes apart are autocorrelated, so the tests can over-flag. The app prints lag-1 and says the limits assume independence.
3. Judges need a public URL. Deploy as soon as testme runs. The publisher key goes in GitHub secrets, never in a file or in chat.
