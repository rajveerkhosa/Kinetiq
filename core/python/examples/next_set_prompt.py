"""
Interactive prompt: logs one set and suggests the next set.

Run from core/python:
    python examples/next_set_prompt.py
"""

from __future__ import annotations

from kinetiq_core import Unit, UserSettings, SetLog, suggest_next_set, make_exercise


TARGET_RPE_RANGE = (7.0, 9.0)


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
        print("Please enter 'lb' or 'kg'.\n")


def ask_int_in_range(prompt: str, lo: int, hi: int) -> int:
    while True:
        s = input(prompt).strip()
        try:
            v = int(s)
            if lo <= v <= hi:
                return v
            print(f"Enter an integer between {lo} and {hi}.\n")
        except ValueError:
            print("Enter a valid integer.\n")


def ask_int_min(prompt: str, lo: int) -> int:
    while True:
        s = input(prompt).strip()
        try:
            v = int(s)
            if v >= lo:
                return v
            print(f"Enter an integer >= {lo}.\n")
        except ValueError:
            print("Enter a valid integer.\n")


def ask_float_min(prompt: str, lo: float) -> float:
    while True:
        s = input(prompt).strip()
        try:
            v = float(s)
            if v >= lo:
                return v
            print(f"Enter a number >= {lo}.\n")
        except ValueError:
            print("Enter a valid number.\n")


def ask_rpe(prompt: str = "RPE (1–10): ") -> float:
    while True:
        s = input(prompt).strip()
        try:
            v = float(s)
            if 1.0 <= v <= 10.0:
                return v
            print("RPE must be between 1 and 10.\n")
        except ValueError:
            print("Enter a valid number (example: 7.5).\n")


def ask_rep_range() -> tuple[int, int]:
    """
    Gets a valid rep range (min, max).
    """
    while True:
        rep_min = ask_int_min("Rep range MIN (>=1): ", 1)
        rep_max = ask_int_min("Rep range MAX (>=1): ", 1)

        if rep_max < rep_min:
            print("You entered MAX < MIN — swapping them.\n")
            rep_min, rep_max = rep_max, rep_min

        # Sanity limits (avoid typos like 500 reps)
        if rep_max > 100:
            print("Rep range max is too large. Try something like 3–20.\n")
            continue

        return rep_min, rep_max


def main() -> None:
    print("\nKinetiq: Next Set Suggestion (RPE-based)")
    print("Logs one set (weight, reps, RPE) and suggests the next set.")

    # Units
    unit = ask_unit(Unit.LB)
    settings = UserSettings(unit=unit)

    # Exercise
    exercise_name = ask_nonempty("Exercise name (e.g., bench press): ")

    # Rep range
    rep_min, rep_max = ask_rep_range()

    # Create exercise config using presets for increments/max jumps
    exercise = make_exercise(
        name=exercise_name,
        rep_range=(rep_min, rep_max),
        target_rpe_range=TARGET_RPE_RANGE,
        settings=settings,
    )

    print("\n--- Log your set ---")
    weight = ask_float_min(f"Weight used ({unit.value}): ", 0.01)

    # reps performed must be within a reasonable bound; allow slightly outside rep range
    # because users might accidentally do 1 more/less — engine will clamp suggestions.
    reps = ask_int_in_range("Reps performed: ", 1, 100)

    rpe = ask_rpe("How hard was it? RPE (1–10): ")

    last_set = SetLog(weight=weight, reps=reps, rpe=rpe)

    suggestion = suggest_next_set(exercise, last_set, settings, debug=False)

    print("\nNext set recommendation")
    print(f"Exercise: {exercise_name}")
    print(f"Working rep range: {rep_min}–{rep_max}")
    print(f"Your set: {weight} {unit.value} x {reps} @ RPE {rpe}")
    print(f"Next set: {suggestion.next_weight} {suggestion.unit.value} x {suggestion.next_reps}")


if __name__ == "__main__":
    main()
