from kinetiq_core import Unit, UserSettings, SetLog, ExerciseConfig, suggest_next_set, MLState

def test_ml_policy_smoke():
    settings = UserSettings(unit=Unit.LB)
    ex = ExerciseConfig(name="bench_press", rep_range=(5, 8), target_rpe_range=(7.0, 9.0))

    state = MLState()
    history = [
        SetLog(weight=185, reps=5, rpe=8.0),
        SetLog(weight=185, reps=5, rpe=8.2),
        SetLog(weight=185, reps=5, rpe=8.4),
    ]
    last = history[-1]
    sug = suggest_next_set(ex, last, settings, use_ml=True, ml_state=state, user_id="matthew", history=history)
    assert sug.next_reps >= 5 and sug.next_reps <= 8
    assert sug.next_weight > 0
