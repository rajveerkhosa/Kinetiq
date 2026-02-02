from kinetiq_core.units import to_kg, from_kg, round_to_increment
from kinetiq_core.models import Unit

def test_lb_kg_roundtrip():
    w_lb = 225.0
    w_kg = to_kg(w_lb, Unit.LB)
    back = from_kg(w_kg, Unit.LB)
    assert abs(back - w_lb) < 1e-6

def test_round_to_increment():
    assert round_to_increment(187.49, 2.5) == 187.5
    assert round_to_increment(186.26, 2.5) == 187.5  # nearest
