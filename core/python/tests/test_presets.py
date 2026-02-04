from kinetiq_core import Unit, UserSettings, common_presets, make_exercise

def test_presets_lb_increments_and_jumps():
    settings = UserSettings(unit=Unit.LB)
    presets = common_presets(settings)

    assert presets["bench_press"].weight_increment_override == 2.5
    assert presets["bench_press"].max_jump_override == 10.0

    assert presets["squat"].weight_increment_override == 5.0
    assert presets["squat"].max_jump_override == 15.0

    assert presets["deadlift"].weight_increment_override == 5.0
    assert presets["deadlift"].max_jump_override == 15.0

def test_presets_kg_increments_and_jumps():
    settings = UserSettings(unit=Unit.KG)
    squat = make_exercise("squat", (5, 8), settings=settings)
    bench = make_exercise("bench_press", (5, 8), settings=settings)

    assert squat.weight_increment_override == 2.5
    assert squat.max_jump_override == 7.5

    assert bench.weight_increment_override == 1.25
    assert bench.max_jump_override == 5.0
