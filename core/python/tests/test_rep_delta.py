from kinetiq_core.progression import rep_delta_from_rpe

def test_rep_delta_ranges():
    assert rep_delta_from_rpe(2.0) == 3
    assert rep_delta_from_rpe(5.0) == 2
    assert rep_delta_from_rpe(7.5) == 1
    assert rep_delta_from_rpe(8.8) == 0
    assert rep_delta_from_rpe(9.6) == -1
