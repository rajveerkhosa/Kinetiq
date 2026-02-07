"""
Interactive CLI for Kinetiq.

Run from core/python:
    python examples/next_set_prompt.py
"""

from __future__ import annotations

from kinetiq_core import (
    Unit,
    UserSettings,
    SetLog,
    suggest_next_set,
    make_exercise,
)

TARGET_RPE_RANGE = (7.0, 9.0)


# -----------------------
# Input helpers
# -----------------------

def ask_nonempty(prompt: str) -> str:
    while True:
        s = input(prompt).strip()
        if s:
            return s
        print("Please enter a value.\n")


def ask_unit(default: Unit = Unit.LB) -> Unit:
    while True:
        s = input(f"Units (lb/kg) [{default.value}]: ").strip().lower()
        if s == "":
            return default
        if s in ("lb", "lbs"):
            return Unit.LB
        if s in ("kg", "kgs"):
            return Unit.KG
        print("Enter 'lb' or 'kg'.\n")


def ask_int_min(prompt: str, lo: int) -> int:
    while True:
        try:
            v = int(input(prompt).strip())
            if v >= lo:
                return v
            print(f"Must be ≥ {lo}.\n")
        except ValueError:
            print("Enter a valid integer.\n")


def ask_float_min(prompt: str, lo: float) -> float:
    while True:
        try:
            v = float(input(prompt).strip())
            if v >= lo:
                return v
            print(f"Must be ≥ {lo}.\n")
        except ValueError:
            print("Enter a valid number.\n")


def ask_rpe(prompt: str = "RPE (1–10): ") -> float:
    while True:
        try:
            v = float(input(prompt).strip())
            if 1.0 <= v <= 10.0:
                return v
            print("RPE must be between 1 and 10.\n")
        except ValueError:
            print("Enter a valid number (e.g. 7.5).\n")


def ask_rep_range() -> tuple[int, int]:
    while True:
        rep_min = ask_int_min("Rep range MIN (≥1): ", 1)
        rep_max = ask_int_min("Rep range MAX (≥1): ", 1)

        if rep_max < rep_min:
            print("MAX < MIN — swapping values.\n")
            rep_min, rep_max = rep_max, rep_min

        if rep_max > 100:
            print("Rep range too large. Use something like 3–20.\n")
            continue

        return rep_min, rep_max


# -----------------------
# Main program
# -----------------------

def main() -> None:
    print("\nKinetiq — Next Set Recommendation")
    print("RPE-based autoregulation (target RPE always 7–9)\n")

    # Units
    unit = ask_unit(Unit.LB)
    settings = UserSettings(unit=unit)

    # Exercise
    exercise_name = ask_nonempty("Exercise name (e.g. bench_press): ")

    # Rep range
    rep_min, rep_max = ask_rep_range()

    # Build exercise config (uses preset increments + max jumps)
    exercise = make_exercise(
        name=exercise_name,
        rep_range=(rep_min, rep_max),
        target_rpe_range=TARGET_RPE_RANGE,
        settings=settings,
    )

    print("\n--- Log your set ---")
    weight = ask_float_min(f"Weight used ({unit.value}): ", 0.01)
    reps = ask_int_min("Reps performed: ", 1)
    rpe = ask_rpe("How hard was it? RPE (1–10): ")

    last_set = SetLog(weight=weight, reps=reps, rpe=rpe)

    suggestion = suggest_next_set(
        exercise=exercise,
        last_set=last_set,
        settings=settings,
        debug=False,
    )

    print("\nNext set recommendation")
    print(f"Exercise: {exercise_name}")
    print(f"Working rep range: {rep_min}–{rep_max}")
    print(f"Your set: {weight} {unit.value} x {reps} @ RPE {rpe}")
    print(f"Next set: {suggestion.next_weight} {suggestion.unit.value} x {suggestion.next_reps}")


if __name__ == "__main__":
    main()
