from kinetiq_core.models import Unit, UserSettings, ExerciseConfig, SetLog
from kinetiq_core.rpe_rules import suggest_next_set_from_rpe

def base():
    settings = UserSettings(unit=Unit.LB, lb_increment=2.5, max_jump_lb=10.0)
    cfg = ExerciseConfig(name="bench", rep_range=(5, 8), target_rpe_range=(7.0, 9.0))
    return settings, cfg

def test_too_easy_increases_weight_first_and_resets_reps():
    settings, cfg = base()
    last = SetLog(weight=185, reps=7, rpe=5.0)  # below 7.0
    sug = suggest_next_set_from_rpe(last, cfg, settings)
    assert sug.action == "add_weight"
    assert sug.next_weight > 185
    assert sug.next_reps == 5


def test_too_easy_at_rep_cap_add_weight_reset_to_rep_min():
    settings, cfg = base()
    last = SetLog(weight=185, reps=8, rpe=6.5)
    sug = suggest_next_set_from_rpe(last, cfg, settings)
    assert sug.action == "add_weight"
    assert sug.next_reps == 5
    assert sug.next_weight > 185

def test_too_hard_low_reps_lower_weight():
    settings, cfg = base()
    last = SetLog(weight=185, reps=5, rpe=9.8)
    sug = suggest_next_set_from_rpe(last, cfg, settings)
    assert sug.action == "lower_weight"
    assert sug.next_weight < 185

def test_in_target_progress_reps():
    settings, cfg = base()
    last = SetLog(weight=185, reps=5, rpe=8.0)
    sug = suggest_next_set_from_rpe(last, cfg, settings)
    assert sug.action == "add_reps"
    assert 5 <= sug.next_reps <= 8
    assert sug.next_reps > 5

def test_in_target_at_cap_manageable_add_weight():
    settings, cfg = base()
    last = SetLog(weight=185, reps=8, rpe=7.2)
    sug = suggest_next_set_from_rpe(last, cfg, settings)
    assert sug.action == "add_weight"
    assert sug.next_reps == 5
    assert sug.next_weight > 185

def test_too_easy_weight_first_resets_reps_to_min():
    settings, cfg = base()
    last = SetLog(weight=185, reps=7, rpe=2.0)  # too easy => weight-first
    sug = suggest_next_set_from_rpe(last, cfg, settings)
    assert sug.action == "add_weight"
    assert sug.next_weight > 185
    assert sug.next_reps == cfg.rep_range[0]  # rep_min
