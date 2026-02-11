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

    # Use ML or rules
    use_ml: bool = False


@dataclass
class SimLifter:
    base_strength: float = 185.0
    sensitivity_weight: float = 1.0 / 25.0
    sensitivity_reps: float = 1.0 / 2.5

    fatigue_per_set: float = 0.20
    readiness_noise: float = 0.60
    rpe_noise: float = 0.25

    adapt_good: float = 0.55
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


def plot_records(history: List[SetLog], title: str) -> None:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib not installed. Run: pip install matplotlib")
        return

    xs = list(range(1, len(history) + 1))
    ws = [s.weight for s in history]
    rs = [s.reps for s in history]
    rpes = [s.rpe for s in history]

    plt.figure()
    plt.plot(xs, ws, marker="o", markersize=3)
    plt.title(f"{title} — Weight Over Time")
    plt.xlabel("Set #")
    plt.ylabel("Weight (lb)")
    plt.tight_layout()
    plt.show()

    plt.figure()
    plt.plot(xs, rs, marker="o", markersize=3)
    plt.title(f"{title} — Reps Over Time")
    plt.xlabel("Set #")
    plt.ylabel("Reps")
    plt.tight_layout()
    plt.show()

    plt.figure()
    plt.plot(xs, rpes, marker="o", markersize=3)
    plt.title(f"{title} — RPE Over Time")
    plt.xlabel("Set #")
    plt.ylabel("RPE")
    plt.ylim(1, 10)
    plt.tight_layout()
    plt.show()


def main() -> None:
    cfg = WeeklySimConfig(
        weeks=16,
        sessions_per_week=2,
        sets_per_session=4,
        exercise_name="bench_press",
        rep_range=(5, 8),
        start_weight=185.0,
        start_reps=5,
        seed=7,
        use_ml=False,
    )

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

    history: List[SetLog] = []

    # Seed initial set
    day0 = lifter.sample_day_readiness()
    rpe0 = lifter.rpe_for_set(cfg.start_weight, cfg.start_reps, rep_min, 0, day0)
    current = SetLog(weight=cfg.start_weight, reps=cfg.start_reps, rpe=rpe0)
    history.append(current)

    print("\nKinetiq Weekly Simulation (JEFF-STYLE B — RULES mode)")
    print("Double progression + RPE drop-by-1 trigger for load increases.\n")
    print(
        f"Exercise: {cfg.exercise_name} | Rep range: {rep_min}-{rep_max} | "
        f"Target RPE: {TARGET_RPE_RANGE[0]}–{TARGET_RPE_RANGE[1]}"
    )
    print(f"Weeks: {cfg.weeks} | Sessions/week: {cfg.sessions_per_week} | Sets/session: {cfg.sets_per_session}")
    print("=" * 92)

    total_sets = 0
    in_zone_count = 0

    for week in range(1, cfg.weeks + 1):
        for sess in range(1, cfg.sessions_per_week + 1):
            day_readiness = lifter.sample_day_readiness()
            session_rpes: List[float] = []

            print(f"\nWeek {week:02d} — Session {sess}/2  (true base_strength≈{lifter.base_strength:.1f} lb)")
            print("-" * 92)

            # ----------------------------
            # TOP SET decides progression
            # ----------------------------
            top_sug = suggest_next_set(
                exercise=ex,
                last_set=current,
                settings=settings,
                debug=False,
                use_ml=cfg.use_ml,
                ml_state=None,
                user_id="sim_user",
                history=history,
            )

            # Perform TOP SET
            top_rpe = lifter.rpe_for_set(
                weight=float(top_sug.next_weight),
                reps=int(top_sug.next_reps),
                rep_min=rep_min,
                set_in_session=0,
                day_readiness=day_readiness,
            )
            top_performed = SetLog(weight=float(top_sug.next_weight), reps=int(top_sug.next_reps), rpe=float(top_rpe))
            history.append(top_performed)
            current = top_performed
            session_rpes.append(top_rpe)

            total_sets += 1
            in_zone = TARGET_RPE_RANGE[0] <= top_rpe <= TARGET_RPE_RANGE[1]
            in_zone_count += 1 if in_zone else 0
            zone = "✅" if in_zone else "⚠️"
            print(
                f"Set 1 (TOP): {zone} did {top_performed.weight:.1f} x {top_performed.reps} @ RPE {top_performed.rpe:.1f} "
                f"| action={top_sug.action} → next {top_sug.next_weight:.1f}x{top_sug.next_reps}"
            )

            # ----------------------------
            # BACKOFF SETS: repeat top prescription
            # Only auto-reduce if too hard.
            # ----------------------------
            backoff_weight = top_performed.weight
            backoff_reps = top_performed.reps

            for set_idx in range(1, cfg.sets_per_session):
                performed_rpe = lifter.rpe_for_set(
                    weight=float(backoff_weight),
                    reps=int(backoff_reps),
                    rep_min=rep_min,
                    set_in_session=set_idx,
                    day_readiness=day_readiness,
                )

                # Safety adjustment mid-session if it's too hard
                if performed_rpe > TARGET_RPE_RANGE[1] and backoff_reps > rep_min:
                    backoff_reps -= 1
                    performed_rpe = lifter.rpe_for_set(
                        weight=float(backoff_weight),
                        reps=int(backoff_reps),
                        rep_min=rep_min,
                        set_in_session=set_idx,
                        day_readiness=day_readiness,
                    )

                performed = SetLog(weight=float(backoff_weight), reps=int(backoff_reps), rpe=float(performed_rpe))
                history.append(performed)
                current = performed
                session_rpes.append(performed_rpe)

                total_sets += 1
                in_zone = TARGET_RPE_RANGE[0] <= performed_rpe <= TARGET_RPE_RANGE[1]
                in_zone_count += 1 if in_zone else 0
                zone = "✅" if in_zone else "⚠️"

                print(
                    f"Set {set_idx+1} (BK): {zone} did {performed.weight:.1f} x {performed.reps} @ RPE {performed.rpe:.1f} "
                    f"| action=stay → next {performed.weight:.1f}x{performed.reps}"
                )

            lifter.adapt_after_session(session_rpes)

    hit_rate = (in_zone_count / total_sets) if total_sets else 0.0
    print("\n" + "=" * 92)
    print(f"Total sets: {total_sets} | Target-zone hit rate: {hit_rate*100:.0f}%")
    print("Tip: With Jeff-style session-based progression, hit rate should usually be higher and oscillation lower.")

    plot_records(history, title="Kinetiq Jeff-Style Simulation")


if __name__ == "__main__":
    main()
