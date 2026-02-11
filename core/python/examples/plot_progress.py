from __future__ import annotations

import random
from dataclasses import dataclass
from typing import List, Tuple, Optional

from kinetiq_core import (
    Unit,
    UserSettings,
    SetLog,
    ExerciseConfig,
    suggest_next_set,
)

# Optional ML
try:
    from kinetiq_core import MLState
except Exception:
    MLState = None

TARGET_RPE_RANGE = (7.0, 9.0)


@dataclass
class WeeklySimConfig:
    weeks: int = 16
    sessions_per_week: int = 2
    sets_per_session: int = 4

    exercise_name: str = "bench_press"
    rep_range: Tuple[int, int] = (5, 8)

    start_weight: float = 185.0
    start_reps: int = 5

    seed: Optional[int] = 7

    # ✅ ML toggle
    use_ml: bool = True


@dataclass
class SimLifter:
    base_strength: float = 185.0
    sensitivity_weight: float = 1.0 / 25.0
    sensitivity_reps: float = 1.0 / 2.5

    fatigue_per_set: float = 0.18
    readiness_noise: float = 0.60
    rpe_noise: float = 0.25

    adapt_good: float = 0.60
    adapt_bad: float = 0.10

    def sample_day_readiness(self) -> float:
        return random.uniform(-self.readiness_noise, self.readiness_noise)

    def rpe_for_set(
        self,
        weight: float,
        reps: int,
        rep_min: int,
        set_in_session: int,
        day_readiness: float,
    ) -> float:
        rpe = 7.0
        rpe += (weight - self.base_strength) * self.sensitivity_weight
        rpe += (reps - rep_min) * self.sensitivity_reps
        rpe += set_in_session * self.fatigue_per_set
        rpe -= day_readiness
        rpe += random.uniform(-self.rpe_noise, self.rpe_noise)
        return max(1.0, min(10.0, rpe))

    def adapt_after_session(self, session_rpes: List[float]) -> None:
        if not session_rpes:
            return
        in_zone = sum(1 for r in session_rpes if TARGET_RPE_RANGE[0] <= r <= TARGET_RPE_RANGE[1])
        rate = in_zone / len(session_rpes)
        self.base_strength += self.adapt_good if rate >= 0.60 else self.adapt_bad


@dataclass
class SimRecord:
    week: int
    session_in_week: int
    set_in_session: int
    global_set: int

    weight: float
    reps: int
    rpe: float

    action: str
    next_weight: float
    next_reps: int


def simulate_over_weeks(cfg: WeeklySimConfig) -> List[SimRecord]:
    if cfg.seed is not None:
        random.seed(cfg.seed)

    rep_min, rep_max = cfg.rep_range

    settings = UserSettings(unit=Unit.LB)
    ex = ExerciseConfig(
        name=cfg.exercise_name,
        rep_range=(rep_min, rep_max),
        target_rpe_range=TARGET_RPE_RANGE,
    )

    lifter = SimLifter(base_strength=cfg.start_weight)

    # ✅ persistent ML state (learns across all weeks)
    ml_state = None
    if cfg.use_ml:
        if MLState is None:
            print("⚠️ MLState not available; running RULES mode.\n")
            cfg.use_ml = False
        else:
            ml_state = MLState()

    history: List[SetLog] = []
    records: List[SimRecord] = []

    # Seed initial set
    day0 = lifter.sample_day_readiness()
    rpe0 = lifter.rpe_for_set(cfg.start_weight, cfg.start_reps, rep_min, 0, day0)
    current = SetLog(weight=cfg.start_weight, reps=cfg.start_reps, rpe=rpe0)
    history.append(current)

    mode = "ML (guardrailed by rules)" if cfg.use_ml else "RULES"
    print(f"\nKinetiq Weekly Simulation ({mode})")
    print(
        f"Exercise: {cfg.exercise_name} | Rep range: {rep_min}-{rep_max} | "
        f"Target RPE: {TARGET_RPE_RANGE[0]}–{TARGET_RPE_RANGE[1]}"
    )
    print(f"Weeks: {cfg.weeks} | Sessions/week: {cfg.sessions_per_week} | Sets/session: {cfg.sets_per_session}")
    print("=" * 92)

    gset = 0

    for week in range(1, cfg.weeks + 1):
        for sess in range(1, cfg.sessions_per_week + 1):
            day_readiness = lifter.sample_day_readiness()
            session_rpes: List[float] = []

            print(f"\nWeek {week:02d} — Session {sess}/2  (true base_strength≈{lifter.base_strength:.1f} lb)")
            print("-" * 92)

            for set_idx in range(cfg.sets_per_session):
                sug = suggest_next_set(
                    exercise=ex,
                    last_set=current,
                    settings=settings,
                    debug=False,
                    use_ml=cfg.use_ml,
                    ml_state=ml_state,
                    user_id="sim_user",
                    history=history,
                )

                performed_rpe = lifter.rpe_for_set(
                    weight=float(sug.next_weight),
                    reps=int(sug.next_reps),
                    rep_min=rep_min,
                    set_in_session=set_idx,
                    day_readiness=day_readiness,
                )

                performed = SetLog(weight=float(sug.next_weight), reps=int(sug.next_reps), rpe=float(performed_rpe))
                history.append(performed)
                current = performed
                session_rpes.append(performed_rpe)

                gset += 1
                in_zone = TARGET_RPE_RANGE[0] <= performed_rpe <= TARGET_RPE_RANGE[1]
                zone = "✅" if in_zone else "⚠️"

                print(
                    f"Set {set_idx+1}: {zone} did {performed.weight:.1f} x {performed.reps} @ RPE {performed.rpe:.1f} "
                    f"| action={sug.action} → next {sug.next_weight:.1f}x{sug.next_reps}"
                )

                records.append(
                    SimRecord(
                        week=week,
                        session_in_week=sess,
                        set_in_session=set_idx + 1,
                        global_set=gset,
                        weight=performed.weight,
                        reps=performed.reps,
                        rpe=performed.rpe,
                        action=sug.action,
                        next_weight=float(sug.next_weight),
                        next_reps=int(sug.next_reps),
                    )
                )

            lifter.adapt_after_session(session_rpes)

    return records


def plot_records(records: List[SimRecord], title: str) -> None:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib not installed. Run: pip install matplotlib")
        return

    xs = [r.global_set for r in records]
    weights = [r.weight for r in records]
    reps = [r.reps for r in records]
    rpes = [r.rpe for r in records]

    plt.figure()
    plt.plot(xs, weights, marker="o", markersize=3)
    plt.title(f"{title} — Weight Over Time")
    plt.xlabel("Set (across weeks)")
    plt.ylabel("Weight (lb)")
    plt.tight_layout()
    plt.show()

    plt.figure()
    plt.plot(xs, reps, marker="o", markersize=3)
    plt.title(f"{title} — Reps Over Time")
    plt.xlabel("Set (across weeks)")
    plt.ylabel("Reps")
    plt.tight_layout()
    plt.show()

    plt.figure()
    plt.plot(xs, rpes, marker="o", markersize=3)
    plt.title(f"{title} — RPE Over Time")
    plt.xlabel("Set (across weeks)")
    plt.ylabel("RPE")
    plt.ylim(1, 10)
    plt.tight_layout()
    plt.show()


if __name__ == "__main__":
    cfg = WeeklySimConfig(
        weeks=16,
        sessions_per_week=2,
        sets_per_session=4,
        exercise_name="bench_press",
        rep_range=(5, 8),
        start_weight=185.0,
        start_reps=5,
        seed=7,
        use_ml=True,  # ✅ turn ML on/off here
    )

    recs = simulate_over_weeks(cfg)
    plot_records(recs, title="Kinetiq Weekly Simulation")
