## Core Strength Engine (RPE-based Autoregulation)

This repo contains a small training engine that supports:
- Any rep range (user-configurable)
- RPE 1–10 effort logging
- Per-set recommendations: add weight, add reps, stay, or lower
- Unit support: lbs now, kg supported via conversion layer

### How it works
1. User logs a set (weight, reps)
2. App asks for RPE (1–10)
3. Engine returns next-set recommendation

### Decision rules (summary)
- If RPE is below target → add reps (until rep_max), then add weight and reset reps to rep_min
- If RPE is in target → add reps toward rep_max; at rep_max add weight if manageable
- If RPE is above target → lower reps or lower weight depending on how close you are to rep_min

See `/core/spec/decision_table.md` for the full decision chart.
