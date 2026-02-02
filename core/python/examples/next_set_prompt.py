"""
Interactive prompt: logs one set and suggests the next set.

Run from core/python:
    python examples/next_set_prompt.py
"""

from kinetiq_core import Unit, UserSettings, SetLog, suggest_next_set, ExerciseConfig


def ask_nonempty(prompt: str) -> str:
    while True:
        s = input(prompt).strip()
        if s:
            return s
        print("Please enter a value.")


def ask_unit() -> Unit:
    while True:
        s = input("Units (lb/kg) [lb]: ").strip().lower()
        if s == "" or s in ("lb", "lbs"):
            return Unit.LB
        if s in ("kg", "kgs"):
            return Unit.KG
        print("Please enter 'lb' or 'kg'.")


def ask_int(prompt: str) -> int:
    while True:
        s = input(prompt).strip()
        try:
            v = int(s)
            if v >= 1:
                return v
            print("Enter an integer >= 1.")
        except ValueError:
            print("Enter a valid integer.")


def ask_float(prompt: str, lo: float | None = None, hi: float | None = None) -> float:
    while True:
        s = input(prompt).strip()
        try:
            v = float(s)
            if lo is not None and v < lo:
                print(f"Enter a number >= {lo}.")
                continue
            if hi is not None and v > hi:
                print(f"Enter a number <= {hi}.")
                continue
            return v
        except ValueError:
            print("Enter a valid number.")


def main():
    print("\nKinetiq: Next Set Suggestion (RPE-based)")
    print("Answer the prompts, then you’ll get a recommendation for the next set.\n")

    # 1) Units (lbs now, kg supported)
    unit = ask_unit()
    settings = UserSettings(unit=unit)

    # 2) Exercise
    exercise_name = ask_nonempty("Exercise name (e.g., bench_press): ")

    # 3) Rep range
    rep_min = ask_int("Rep range MIN (e.g., 5): ")
    rep_max = ask_int("Rep range MAX (e.g., 8): ")
    if rep_max < rep_min:
        rep_min, rep_max = rep_max, rep_min  # auto-fix if user swaps them

    # Optional: target RPE band (common default 7–9)
    use_default_rpe = input("Use default target RPE range 7–9? [Y/n]: ").strip().lower()
    if use_default_rpe in ("n", "no"):
        rpe_min = ask_float("Target RPE MIN (1–10): ", lo=1.0, hi=10.0)
        rpe_max = ask_float("Target RPE MAX (1–10): ", lo=1.0, hi=10.0)
        if rpe_max < rpe_min:
            rpe_min, rpe_max = rpe_max, rpe_min
        target_rpe_range = (rpe_min, rpe_max)
    else:
        target_rpe_range = (7.0, 9.0)

    exercise = ExerciseConfig(
        name=exercise_name,
        rep_range=(rep_min, rep_max),
        target_rpe_range=target_rpe_range,
        # keep increments via presets if you want; for now defaults come from UserSettings
        # you can swap to make_exercise(...) if you want preset increments/jumps
    )

    print("\n--- Log your set ---")
    # 4) Last set performance
    weight = ask_float(f"Weight used ({unit.value}): ", lo=0.01)
    reps = ask_int("Reps performed: ")
    rpe = ask_float("How hard was it? RPE (1–10): ", lo=1.0, hi=10.0)

    last_set = SetLog(weight=weight, reps=reps, rpe=rpe)

    # 5) Suggest next set
    suggestion = suggest_next_set(exercise, last_set, settings, debug=False)

    print("\nNext set recommendation")
    print(f"Exercise: {exercise_name}")
    print(f"Your set: {weight} {unit.value} x {reps} @ RPE {rpe}")
    print(f"Action: {suggestion.action}")
    print(f"Next set: {suggestion.next_weight} {suggestion.unit.value} x {suggestion.next_reps}")
    print(f"Why: {suggestion.explanation}\n")


if __name__ == "__main__":
    main()
