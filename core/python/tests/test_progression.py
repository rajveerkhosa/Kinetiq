from kinetiq_core import Unit
from kinetiq_core.progression import jump_from_rpe_lb, jump_from_rpe


def test_jump_from_rpe_lb_key_points():
    # RPE 1 -> ~10
    assert abs(jump_from_rpe_lb(1.0) - 10.0) < 1e-9
    # RPE 3 -> ~5
    assert abs(jump_from_rpe_lb(3.0) - 5.0) < 1e-9

    # RPE 4 -> 5
    assert abs(jump_from_rpe_lb(4.0) - 5.0) < 1e-9
    # RPE 7 -> 2.5
    assert abs(jump_from_rpe_lb(7.0) - 2.5) < 1e-9

    # RPE 9 -> 0.5
    assert abs(jump_from_rpe_lb(9.0) - 0.5) < 1e-9
    # RPE 10 -> 0
    assert abs(jump_from_rpe_lb(10.0) - 0.0) < 1e-9


def test_jump_from_rpe_units():
    lb = jump_from_rpe(2.0, Unit.LB)
    kg = jump_from_rpe(2.0, Unit.KG)
    assert lb > 0
    assert kg > 0
    # kg should be smaller numerically
    assert kg < lb
