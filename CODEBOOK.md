# Codebook

**One rule:** say, for each thing, whether it is *chosen* or *computed*. Anything the app prints is traceable to either a chosen constant, an assumption, or a function in `app/R/`.

## What is chosen (not computed)

| Name | Value | Where stated in code | Why |
|---|---|---|---|
| Safe storage range (spec limits) | lsl 1.0 °C, usl 6.0 °C | `app/R/limits.R`, `SPEC_LOW`, `SPEC_HIGH`; README §5, §7 | Defines "out of spec". |
| Target | 3.5 °C | `app/R/limits.R`, `TARGET_TEMP`; README §5 | Display only (middle of spec). |
| Subgroup size | 4 | `subgroup_n = 4` (defaults) | Four readings/hour, 15-minute. |
| Baseline | first 48 subgroups | `baseline_subgroups = 48`, `freeze_baseline` | Limits frozen from baseline. |
| Min subgroups | 25 | `min_subgroups = 25` | Must have >= 25 before limits drawn. |
| Trailing window (rolling Ppk) | 96 readings | `rolling_ppk(..., window = 96)`; README §5, forecast.R | 24 hours at 15 minutes. |
| Capability cutoff | 1.0 | README §5, §6 | Cpk >= 1.0 for "capable". |
| Forecast horizon rule | after hour 48; "already out" or `Inf` when none | `hours_to_spec` | Conservative prediction. |
|---|---|---|---|
| Generator threshold | 10 seconds | README §5, §7, app UI (Overview/Backup generator) | **Team-chosen assumption. Not a spec limit and not a control limit.** Set for each site's own test. |
| Seeds | 5300 (data), 5301 (blood types) | `data/make_data.R` | Synthetic data reproducibility. |
| Blood type frequencies (generator input) | O+ 38%, A+ 32%, B+ 9%, O- 7%, A- 6%, AB+ 3%, B- 2%, AB- 1% (sum 98%, renormalized) | `data/make_data.R` (rmultinom); `data/README.md` | Chosen distribution for synthetic draw, not computed from inventory. |

## Computed (function → output)

| Quantity | Function(s) | On screen (where used) |
|---|---|---|
| Subgroup mean, range, sd, variance, n_obs | `subgroup_stats(x, n)` | Fridge Detail (charts) |
| sigma_short | `sigma_short_from_variances` | X-bar/range/s charts, capability |
| sigma_overall | `sigma_overall` | Ppk, capability |
| d2, d3 | `range_constants(n)` | Range limits (ptukey+integrate) |
| c4, B5, B6 | `sd_constants(n)` | s-chart (from lgamma/c4) |
| X-bar limits (center, SE, lcl,ucl, zones) | `xbar_limits` | X-bar chart, zones |
| Range/sd limits | `range_chart_limits`, `sd_chart_limits` | Charts |
| Capability (Cpk, Ppk, gap) | `capability_indices` | Capability tab; Cpk uses sigma_short, Ppk uses sigma_overall, gap = Cpk-Ppk |
| Baseline freeze (limits + cap) | `freeze_baseline` | First 48h, min 25; lag1 stored |
| Special cause tests 1–8 | `special_cause_test_*` | Violations table + meanings |
| Hours to spec | `hours_to_spec` | Fridge card "Out of spec in" |
| Rolling Ppk | `rolling_ppk` | Capability chart (96 readings) |
| Severity, occurrence, urgency | `severity_score`, `worst_occurrence`, `urgency_score` | Fridge card RPN |
| RPN | `rpn` | Fridge card (severity*occurrence*urgency) |
| IMR limits (generator) | `imr_limits` | Generator page, generator_stats |
| Generator stats (projection) | `generator_stats(g)` | Capability tab (copies from generator_analysis/imr) |
| Overview summary, analyses | `overview_summary`, `analyze_*` | Overview, cards |

## Files (roles)

- `app/app.R`: Shiny UI/server (carries captions, renders numbers).
- `app/R/*.R`: Statistical functions (see above).
- `app/qc.R`: Sources all `app/R/*.R`.
- `app/manifest.json`: Bundles deployed files (hand-refreshed; checksums must match LF-normalized MD5).
- `app/data/`: CSVs copied for deployment.
- `tests/`: Assertions (including captions, generator, RPN product, sd-chart display-only, etc).
- `data/`: Source CSVs + `make_data.R` (synthetic; seeds 5300/5301). The two scenario folders `scenario_one_bad/` and `scenario_one_good/` hold hand-tuned alternate `readings.csv` sets (with copied `inventory.csv` and `generator_log.csv`); they are not reproducible from `make_scenarios.R`, which writes a different generated pair into `data/scenario_generated/`. See [`data/README.md`](data/README.md).
- `demo/`: Demo outputs and README.
- `docs/`: Event docs (criteria, prompts, schedule, agents, tools).

## Data variables (three CSVs)

`readings.csv`: fridge_id, timestamp (YYYY-MM-DD HH:MM:SS, 15-min), temp_c (°C), door_open (0/1), on_generator (0/1). Scenario variants in `data/scenario_one_*/*` match the same schema.
`inventory.csv`: fridge_id, blood_type (O+,A+,B+,AB+,O-,A-,B-,AB-), blood_units (count). Display-only for badges/capability. (Same in scenario folders.)
`generator_log.csv`: date (YYYY-MM-DD), transfer_time_sec (seconds). Team-chosen 10 s threshold applies. (Same in scenario folders.)

## Key notes

- Variances divide by n-1. Control limits are center ± 3 SE; zones at 1,2 SE (explained as aid, not control limits).
- Lag-1 printed as a limitation, not used to widen limits.
- Limits frozen after first 48 hours; < 25 subgroups → no limits.
- Cpk uses sigma_short; Ppk uses sigma_overall; gap = Cpk-Ppk. If sigma==0, indices/gap are NA with message.
- RPN = severity × occurrence × urgency (urgency stands in for detection). Verified on every demo fridge.
- Blood type distribution is a chosen synthetic input (renormalized), not computed from inventory.
- Generator statistics in the Capability tab are a projection (copied from `generator_analysis()`), no new formula.
