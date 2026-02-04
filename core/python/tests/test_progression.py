from kinetiq_core import Unit
from kinetiq_core.progression import jump_from_rpe_lb, jump_from_rpe


def test_jump_from_rpe_lb_key_points():
    assert abs(jump_from_rpe_lb(1.0) - 15.0) < 1e-9
    assert abs(jump_from_rpe_lb(3.0) - 10.0) < 1e-9
    assert abs(jump_from_rpe_lb(4.0) - 10.0) < 1e-9
    assert abs(jump_from_rpe_lb(7.0) - 5.0) < 1e-9
    assert abs(jump_from_rpe_lb(9.0) - 5.0) < 1e-9
    assert abs(jump_from_rpe_lb(10.0) - 5.0) < 1e-9


def test_jump_from_rpe_units():
    lb = jump_from_rpe(2.0, Unit.LB)
    kg = jump_from_rpe(2.0, Unit.KG)
    assert lb >= 5.0
    assert kg > 0
    assert kg < lb
