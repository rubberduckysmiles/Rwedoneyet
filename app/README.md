# ColdChain Monitor

ColdChain Monitor watches blood-bank refrigerators (safe range 1 to 6 C) for the operations manager.
It freezes control limits from the first 48 hours, then flags later hours that break them.
Each fridge gets a red, amber, or green badge, a risk number, and the hours until it may leave range.

Start the app (open http://127.0.0.1:5763): `Rscript app/testme.R`
Check the numbers against the known answer in SPEC.md section 4: `Rscript app/workflow.R`

All statistics live in `app/R/`; `app/app.R` only draws them. No secrets are needed.
