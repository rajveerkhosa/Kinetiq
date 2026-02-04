# Decision Table (RPE Autoregulation)

Inputs per set:
- weight
- reps
- RPE (1–10)
User chooses:
- rep_range = [rep_min, rep_max]
- target_rpe_range = [rpe_min, rpe_max]
- increment (lbs/kg), max jump (safety)

Outputs:
- action: add_weight | add_reps | stay | lower_weight | lower_reps
- next_set: (weight, reps)

Rules:

## A) Too hard (RPE > rpe_max)
- If reps <= rep_min: LOWER WEIGHT (one increment, capped by max jump)
- Else: LOWER REPS (by reps_step, clamped to rep range)

## B) Too easy (RPE < rpe_min)
- If reps >= rep_max: ADD WEIGHT (one increment, capped) and RESET reps to rep_min
- Else: ADD REPS (by reps_step, clamped)

## C) In target (rpe_min <= RPE <= rpe_max)
- If reps < rep_max: ADD REPS
- If reps == rep_max:
  - If RPE is “manageable” (<= midpoint of rpe range): ADD WEIGHT and RESET reps to rep_min
  - Else: STAY (repeat the capped set to solidify)
