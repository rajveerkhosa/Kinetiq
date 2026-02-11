from __future__ import annotations

from datetime import datetime

from kinetiq_core import Unit, UserSettings, SetLog, suggest_next_set, make_exercise
from kinetiq_core.storage import append_log, setlog_to_entry, load_logs

TARGET_RPE_RANGE = (7.0, 9.0)


def ask_nonempty(prompt: str) -> str:
    while True:
        s = input(prompt).strip()
        if s:
            return s
        print("❌ Please enter a value.\n")


def ask_unit(default: Unit = Unit.LB) -> Unit:
    while True:
        s = input(f"Units (lb/kg) [{default.value}]: ").strip().lower()
        if s == "":
            return default
        if s in ("lb", "lbs"):
            return Unit.LB
        if s in ("kg", "kgs"):
            return Unit.KG
        print("❌ Enter 'lb' or 'kg'.\n")


def ask_int_min(prompt: str, lo: int) -> int:
    while True:
        try:
            v = int(input(prompt).strip())
            if v >= lo:
                return v
            print(f"❌ Must be ≥ {lo}.\n")
        except ValueError:
            print("❌ Enter a valid integer.\n")


def ask_float_min(prompt: str, lo: float) -> float:
    while True:
        try:
            v = float(input(prompt).strip())
            if v >= lo:
                return v
            print(f"❌ Must be ≥ {lo}.\n")
        except ValueError:
            print("❌ Enter a valid number.\n")


def ask_rpe() -> float:
    while True:
        try:
            v = float(input("How hard was it? RPE (1–10): ").strip())
            if 1.0 <= v <= 10.0:
                return v
            print("❌ RPE must be between 1 and 10.\n")
        except ValueError:
            print("❌ Enter a valid number (e.g. 7.5).\n")


def ask_rep_range() -> tuple[int, int]:
    rep_min = ask_int_min("Rep range MIN (>=1): ", 1)
    rep_max = ask_int_min("Rep range MAX (>=1): ", 1)
    if rep_max < rep_min:
        rep_min, rep_max = rep_max, rep_min
    return rep_min, rep_max


def main() -> None:
    print("\nKinetiq: Next Set Suggestion (RPE-based)")
    print("Logs one set (weight, reps, RPE) and suggests the next set.")
    print("Target RPE is always 7–9.\n")

    unit = ask_unit(Unit.LB)
    settings = UserSettings(unit=unit)

    exercise_name = ask_nonempty("Exercise name (e.g., bench_press): ")
    rep_min, rep_max = ask_rep_range()

    ex = make_exercise(
        name=exercise_name,
        rep_range=(rep_min, rep_max),
        target_rpe_range=TARGET_RPE_RANGE,
        settings=settings,
    )

    print("\n--- Log your set ---")
    weight = ask_float_min(f"Weight used ({unit.value}): ", 0.01)
    reps = ask_int_min("Reps performed: ", 1)
    rpe = ask_rpe()

    last = SetLog(weight=weight, reps=reps, rpe=rpe)

    sug = suggest_next_set(ex, last, settings, debug=False)

    # log it
    ts = datetime.now().isoformat(timespec="seconds")
    append_log(exercise_name, setlog_to_entry(last, ts))

    print("\nNext set recommendation")
    print(f"Exercise: {exercise_name}")
    print(f"Working rep range: {rep_min}–{rep_max}")
    print(f"Your set: {weight:.1f} {unit.value} x {reps} @ RPE {rpe:.1f}")
    print(f"Action: {sug.action}")
    print(f"Next set: {sug.next_weight:.1f} {sug.unit.value} x {sug.next_reps}")
    print(f"Why: {sug.explanation}\n")

    print("Saved this set to data/set_logs.json")
    print("To graph progression later: python examples/plot_progress.py\n")


if __name__ == "__main__":
    main()
