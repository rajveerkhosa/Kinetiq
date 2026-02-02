from kinetiq_core import Unit, UserSettings, ExerciseConfig, SetLog, suggest_next_set

def test_engine_entrypoint():
    settings = UserSettings(unit=Unit.LB, lb_increment=2.5, max_jump_lb=10.0)
    squat = ExerciseConfig(name="squat", rep_range=(8, 12), target_rpe_range=(7.0, 9.0))

    last = SetLog(weight=225, reps=10, rpe=8.0)
    sug = suggest_next_set(squat, last, settings)
    assert sug.unit == Unit.LB
    assert sug.next_reps in range(8, 13)
