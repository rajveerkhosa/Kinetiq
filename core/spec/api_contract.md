# API Contract (App ↔ Core)

## Input (example JSON)
```json
{
  "exercise": {
    "name": "bench_press",
    "rep_range": [5, 8],
    "target_rpe_range": [7.0, 9.0],
    "weight_increment_override": null,
    "max_jump_override": null,
    "reps_step": 1
  },
  "settings": {
    "unit": "lb",
    "lb_increment": 2.5,
    "kg_increment": 1.25,
    "max_jump_lb": 10.0,
    "max_jump_kg": 5.0
  },
  "last_set": { "weight": 185, "reps": 8, "rpe": 7.5 }
}
