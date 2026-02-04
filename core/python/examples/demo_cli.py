from kinetiq_core import Unit, UserSettings, ExerciseConfig, SetLog, suggest_next_set

def main():
    settings = UserSettings(unit=Unit.LB, lb_increment=2.5, max_jump_lb=10.0)

    # user chooses any rep range
    bench = ExerciseConfig(
        name="bench_press",
        rep_range=(5, 8),
        target_rpe_range=(7.0, 9.0),
    )

    print("Kinetiq demo (RPE-based recommendations)")
    print("Enter your last set, then your RPE (1–10). Ctrl+C to quit.\n")

    current_weight = 185.0
    current_reps = 6

    while True:
        try:
            print(f"Current target set: {current_weight} lb x {current_reps}")
            reps = int(input("Reps performed: ").strip())
            rpe = float(input("RPE (1-10): ").strip())
            weight = float(input(f"Weight used ({settings.unit.value}): ").strip())

            last = SetLog(weight=weight, reps=reps, rpe=rpe)
            sug = suggest_next_set(bench, last, settings, debug=False)

            print(f"\n→ Action: {sug.action}")
            print(f"→ Next set: {sug.next_weight} {sug.unit.value} x {sug.next_reps}")
            print(f"→ Why: {sug.explanation}\n")

            current_weight = sug.next_weight
            current_reps = sug.next_reps

        except KeyboardInterrupt:
            print("\nBye.")
            break
        except Exception as e:
            print(f"\nError: {e}\n")

if __name__ == "__main__":
    main()
