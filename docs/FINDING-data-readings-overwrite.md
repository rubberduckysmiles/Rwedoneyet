# FINDING: `data/readings.csv` was overwritten with the `scenario_one_good` data

**Reported:** 2026-10-20
**Commit under investigation:** `654f766` "fixing data", authored by Hannah Brine (pushed 2026-10-19 22:10 -0700)
**State of `main`:** `8b0837a` — **red, before any further work**

This is reported rather than fixed, per H-25's definition of done: *"If the pipeline disagrees
with what the data looks like, that is a finding to report, not a test to bend."*

---

## 1. `main` is red right now

Run in a clean worktree at `origin/main` (`8b0837a`), with no other work present:

```
FAIL 62 | WARN 0 | SKIP 0 | PASS 945
```

The failures are not in one place. They include:

| test | failure |
|---|---|
| `test-app_scenario_picker.R:43` | H-31's own *"app/data mirrors data/ byte for byte"* assertion |
| `test-app_bloodtype_section.R:33,40,44,46` | expects 180 bags at risk, app now reports 0 |
| `test-sd_chart.R` (12 lines, 62 assertions) | every F02 Cpk/Ppk/RPN/occurrence/urgency captured value moved |

H-31's result line claims `tests PASS 1007 (was 974, +33)` and `all match`. That was true when
H-31 was committed. It stopped being true at `654f766`, which landed afterwards.

## 2. What `654f766` did

`data/readings.csv` is now **byte-identical to `data/scenario_one_good/readings.csv`**:

```
data/readings.csv == data/scenario_one_good/readings.csv          TRUE
data/readings.csv == app/data/readings.csv                        FALSE
pre-654f766 root  == app/data/readings.csv                        TRUE
data/inventory.csv == data/scenario_one_good/inventory.csv        TRUE
data/generator_log.csv == data/scenario_one_good/generator_log.csv TRUE
```

All three files at the repo root were replaced by the "good" scenario set. **`app/data/` was not
updated**, which is what breaks H-31's mirror test: `app/data/readings.csv` is the only file of
the nine under `app/data/` that no longer matches `data/`.

Before this commit, the root data and `app/data/` were byte-identical — so this is a divergence
introduced by the commit, not a pre-existing one.

## 3. Why it matters: the textbook failure left the demo

| fridge | before `654f766` (still in `app/data/`) | after |
|---|---|---|
| **F02** the drifting fridge | 3.49 → **7.27 °C** rising across the week, 191 readings out of range | flat **1.504 °C**, range 1.00–2.00, 0 out of range |
| **F04** the blackout | spike to **7.40 °C**, 3 readings out of range | 3.18–3.88, nothing happens |
| **F03** the excursion | spike to **7.80 °C** | 3.08–4.00 |
| **F06** | 3.51 ± 0.14, nothing out of range | **4.99 ± 0.56**, the only fridge with out-of-range readings (16) |

The app's verdicts follow the data:

| | needing action | red | amber | green | bags at risk |
|---|---|---|---|---|---|
| `data/` (repo) | 2/6 | F06 | F02 | 4 | 67 |
| `app/data/` (what ships) | 4/6 | F02, F03 | F06, F05 | 2 | 283 |

Two consequences worth a decision:

1. **The demo no longer contains a textbook failure.** F02 is amber only because a *steady*
   1.5 °C leaves Cpk below 1 — a narrow-distribution capability flag, not a failure. F06 is the
   only fridge with an out-of-range reading, and it sits at a stable 4.99 °C. Anything a judge
   or the README describes as "the drifting fridge" or "the blackout fridge" no longer matches
   the data.
2. **The repo and the app disagree about the same six fridges.** `data/` says 2 need action and
   F04 is green; `app/data/` says 4 need action and F02 is red. Both cannot be right, and the
   deployed app is showing the second.

## 4. Three commits did nothing

`79f23d5`, `6fb71d0` ("fixing one bad") and `8b0837a` ("fixing one good") are **empty commits** —
`--shortstat` reports no files changed for any of them:

```
8b0837a fixing one good
6fb71d0 fixing one bad
654f766 fixing data
 1 file changed, 3966 insertions(+), 3966 deletions(-)
```

This is consistent with a push where the intended data files never got staged, and it is worth
asking Hannah what those two commits were meant to carry.

## 5. What is NOT affected

- No statistics code changed. `app/R/` is untouched by the pull.
- The two committed scenario sets are internally unchanged and still mirror correctly between
  `data/` and `app/data/`.
- The `deploy-shiny-r.yml` workflow and the live bundle are unaffected; the live app is simply
  serving the older, still-coherent `app/data/` copy.

## 6. Options (needs a decision from the team, not from the agent)

**A. Restore the demo as it was.** Reset `data/readings.csv` (and the inventory and generator
files) to `e41d741`, the hand-tuned demo from H-02, which is byte-identical to `app/data/`. This
makes the suite green again and keeps F02 drifting and F04 blacking out. Cost: it reverts a
teammate's committed change, so it should be a teammate's call.

**B. Adopt the good scenario as the demo.** Copy `data/readings.csv` into `app/data/readings.csv`
so the mirror test passes. Cheap and green, but the shipped demo loses its textbook failure and
every document that names F02 as the drifting fridge becomes false and needs rewriting.

**C. Split the difference.** Keep the hand-tuned demo at the root, and make the scenario picker
the only place the two scenario sets appear. This is what H-31's structure already implies; the
root `data/` folder was never meant to be a scenario.

Whichever is chosen, `main` should go green before H-28 is checked in, because H-28's definition
of done requires the per-fridge demo numbers to be re-measured and truthfully documented — and
those numbers are exactly what this finding is about.

---

## Reproducing this

```powershell
git worktree add "$env:TEMP\main-check" origin/main
cd "$env:TEMP\main-check"
Rscript -e "testthat::set_max_fails(Inf); testthat::test_dir('tests')"
# FAIL 62 | WARN 0 | SKIP 0 | PASS 945
```
