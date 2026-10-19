# SPEC: Six Sigma Hackathon team project

What your tool IS. Your agent reads this before every task. Where the code and this file
disagree, the code is the bug: change this file first, then the code.

Most of this page is already decided by the event and the [rubric](docs/criteria.md).
**Only the `FILL IN` lines change, and you do not have to write them by hand:** describe your app and ask your agent to update them. They depend on the prompt your team picks at kickoff
(prompts are secret until then, see [`docs/prompts.md`](docs/prompts.md)) and on your team.
The examples after each `FILL IN` show the shape of an answer. They are not hints about the prompts.

## 1. Team and prompt
- **Team name:** Keep It Cool
- **Track:** Virtual DL Challenge (7 days). See [`docs/schedule.md`](docs/schedule.md).
- **Prompt we chose:** Blood Banks, copied from the [Devpost](https://six-sigma-hackathon.devpost.com/) challenge page at kickoff.
- **Our public repo:** github.com/rubberduckysmiles/Rwedoneyet

## 2. User and use case (rubric: scope 5, user and use case 5)
- **User:** the blood-bank operations manager who watches the refrigerators that store red blood cells
- **Decision the tool helps them make, and when:** which fridge to service or evacuate before the next shift, so the bags do not leave 1–6 °C
- **Why this matches the prompt:** Blood Banks asks for a tool that tracks supply integrity in failing refrigerators and flags the failure before the blood is lost.

## 3. Inputs (rubric: minimal inputs 5)
Only what this user can actually measure or already knows. Fewer is better; every input a user
cannot measure costs points.

| Input | Type and units | Where the user gets it |
|---|---|---|
| `readings.csv`: fridge_id, timestamp, temp_c, door_open, on_generator. One row every 15 minutes. | temp_c in °C. door_open and on_generator are 1 or 0. | the fridge logger |
| `inventory.csv`: fridge_id, blood_type, blood_units | count of red-cell bags of each ABO/Rh type in that fridge, one row per fridge per type | the inventory the manager already keeps |
| `generator_log.csv` (optional): date, transfer_time_sec | seconds from power loss to generator load | the generator transfer test |

## 4. The statistics, and why (rubric: valid QC analysis 25)
Say the method in words before any code exists. Load the `stats-first-steering` skill first.
- **Method:** Each hour is a subgroup of 4 temperatures. Sigma short is the square root of the mean within-hour sample variance, from the first 48 hours only. The X-bar center is the grand mean. X-bar limits are that center plus or minus 3 sigma-short over square root of 4. d2 and d3 are computed from the range of n standard normals with `ptukey`, not read from a table. The range chart center is d2 times sigma short, and its limits are (d2 ± 3 d3) times sigma short, with the lower limit held at 0. Cpk uses sigma short. Ppk uses the sample standard deviation of all baseline readings. Both use spec limits 1 °C and 6 °C. Eight special-cause tests run on the X-bar chart. Test 1 also runs on the range chart, and test 1 also runs on a standard deviation chart. The s-chart constants are computed, not read from a table: c4 = √(2/(n−1))·Γ(n/2)/Γ((n−1)/2), so E[s] = c4·sigma short and sd(s) = sigma short·√(1−c4²). Its center is c4·sigma short and its limits are B5·sigma short and B6·sigma short, where B5 = max(0, c4 − 3√(1−c4²)) and B6 = c4 + 3√(1−c4²), with the lower limit held at 0. For n = 4 this gives c4 = 0.9213177, B6 = 2.0877494 and B5 = 0. The s-chart is display only: its flags never reach the badge, the risk priority number, the units at risk or the violations table. A straight line through the later subgroup means gives hours until 1 °C or 6 °C.
- **Why it fits the use case:** A slow compressor drift, a door left open, a stuck sensor, or a late generator shows up as a pattern on the hourly chart before the manager has to move the bags.
- **Assumptions and how the tool checks them:** Sample variances divide by n − 1. The 3-sigma limits assume a normal, independent process. The Capability page shows a histogram against 1 °C, 3.5 °C, and 6 °C. Lag-1 autocorrelation of the baseline readings is printed as a limitation and is not used to widen the limits. Limits stay frozen after the first 48 hours, and the app says so. A baseline with fewer than 25 subgroups does not get limits.
- **Known-answer check:** Ten hours, four readings each, every hour mean exactly 3.5 °C. Rows: (3.2, 3.4, 3.6, 3.8), (3.3, 3.5, 3.5, 3.7), (3.1, 3.4, 3.6, 3.9), (3.4, 3.4, 3.6, 3.6), (3.0, 3.5, 3.5, 4.0), (3.2, 3.3, 3.7, 3.8), (3.3, 3.4, 3.6, 3.7), (3.1, 3.5, 3.5, 3.9), (3.2, 3.6, 3.6, 3.6), (3.4, 3.5, 3.5, 3.6). Sum of squares = 1.98. Mean variance = 0.066. Sigma short = √0.066 = 0.2569046516. Sigma overall = √(1.98/39) = 0.2253202849. X-bar limits = 3.8853569774 and 3.1146430226. For n = 4, d2 = 2.0587507460 and d3 = 0.8798082028. Range center = 0.5289026431, upper = 1.2069831025, lower = 0. Cpk = 3.2437456007. Ppk = 3.6984390192. Gap = −0.4546934185. Lag-1 autocorrelation = −0.2174115934. The gap is negative here because the hour means do not move. Drift check: add 0, 0, 0, 0, 0, 0.2, 0.4, 0.6, 0.8, 1.0 °C to those ten hours. Grand mean = 3.8, sigma short stays 0.2569046516, sigma overall = 0.4290717470, Cpk = 2.8544961286, Ppk = 1.7091158726, gap = +1.1453802560. Also, n = 5 must give d2 = 2.3259289473 and d3 = 0.8640819411. Constant data, every reading 3.5 °C: both sigmas are 0, and Cpk and Ppk are missing with a message, never infinity or 0.

Fixed for every team:
- The statistic lives in **one plain, tested function** (`app/qc.py` or `app/qc.R`). The API, app or
  package only calls it and displays the result. No statistics inside UI code.
- Every statistic has a test against a known answer and a degenerate case (constant data, n = 1, missing values).
- You can explain every number the tool prints. If you cannot, it is not done.

## 5. Delivery (rubric: working tool 25)
- **Stack:** dashboard (Shiny)
- **Starting demo:** `demos/shinyapp/`, copied into `app/`

Fixed for every team:
- Start from **one** demo in `demos/`, copied to `app/`. Keep its four-script contract
  (`testme`, `manifestme`, `deployme`, `README.md`); `testme` starts the tool with one command.
- Deployed on the course **Posit Connect** server with a public URL (publisher key handed out at the
  event). Deploy early: copy one workflow from
  [`.claude/skills/connect-publish/workflows/`](.claude/skills/connect-publish/workflows/).
- A small tool that runs beats a large tool that does not.

## 6. Outputs
- **What the user sees:** Bank of Bloody Mary. Overview shows fridges needing action, blood units at risk, average Ppk, and the last generator transfer, then fridge cards sorted by risk priority number. Fridge Detail shows an X-bar chart over a range chart over a standard deviation chart, with the baseline shaded and flagged hours marked, then the blood types held in that fridge with each type's at-risk bags marked. Capability shows Cpk, Ppk, the gap, a histogram with lines at 1 °C, 3.5 °C, and 6 °C, a rolling 24-hour Ppk, and one sentence: "capable and stable", "inside the spec width, but not stable", or "not capable". How to read the badge: red means act this shift, amber means watch, green means leave it.

## 7. Test datasets and codebook (rubric: demo 10, datasets 5, codebook 5)
2-3 small CSVs in `data/`, invented but shaped like real field data, each showing one behavior.
`data/README.md` is the codebook: every file, every column with units, and what it would take to
collect this data for real.
- **Datasets:** `readings.csv` (six fridges, one reading every 15 minutes: healthy, drifting compressor, door-open spikes, blackout with a slow generator, flatlined sensor, and a second healthy fridge with a normal defrost cycle), `inventory.csv` (bags in each fridge, split by blood type: the per-fridge totals are the same as they ever were, and blood type is display only), `generator_log.csv` (transfer time in seconds). The 10-hour hand-check rows live in the tests, not as a fourth CSV.

## 8. Documentation and reproducibility (rubric: docs 10, public repo 5)
- `README.md` says what the tool does, for whom, every input and parameter, how to run it in one
  command, and walks through the demo on each test dataset.
- Public GitHub repo; a fresh clone runs `testme` and the tests pass with no extra steps.
- Submit on Devpost: the repo link plus a demo.

## 9. Out of scope
What we will NOT build, so nobody (human or agent) builds it by accident.
- Default: logins, databases, real customer data, a second statistic before the first one is tested.
- No dollar amounts or costs. No multi-site comparison. No attribute charts. qcc may be used only to cross-check, never as the implementation.
