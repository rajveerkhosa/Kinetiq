from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from datetime import date
from typing import Optional
import psycopg
import httpx
import psycopg.rows
import bcrypt
import os
import secrets
import smtplib
from email.mime.text import MIMEText
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "").replace("postgres://", "postgresql://", 1)
GMAIL_USER = os.getenv("GMAIL_USER")
GMAIL_APP_PASSWORD = os.getenv("GMAIL_APP_PASSWORD")
NINJA_API_KEY = os.getenv("API_KEY")
app = FastAPI()

@app.on_event("startup")
def run_migrations():
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                ALTER TABLE workoutsession
                ADD COLUMN IF NOT EXISTS duration_minutes INTEGER DEFAULT 0
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS password_reset_codes (
                    email TEXT PRIMARY KEY,
                    code TEXT NOT NULL,
                    expires_at TIMESTAMPTZ NOT NULL
                )
            """)
            conn.commit()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -------------------------
# Pydantic Models
# -------------------------
class RegisterUser(BaseModel):
    username: str
    email: EmailStr
    password: str
    first_name: str
    middle_name: Optional[str] = None
    last_name: str
    age: int
    sex: str
    height_ft: int
    height_in: int
    weight_lb: float
    experience_level: str
    journey_started: str

class LoginUser(BaseModel):
    identifier: str  # email or username
    password: str

class CreatePlan(BaseModel):
    user_id: int
    plan_name: str

class AddPlanExercise(BaseModel):
    plan_id: int
    exercise_name: str
    target_sets: int
    target_reps: int
    notes: Optional[str] = None

class LogSession(BaseModel):
    user_id: int
    plan_id: int
    duration_minutes: int
    session_date: str  # "YYYY-MM-DD"
    missed: bool = False

class LogSet(BaseModel):
    session_id: int
    exercise_name: str
    set_number: int
    weight_lb: float
    reps: int
    rpe: Optional[float] = None

class LogPerformance(BaseModel):
    session_id: int
    exercise_name: str
    set_number: int
    actual_reps: int
    actual_weight_lbs: float
    completed: bool = True

# -------------------------
# Routes 
# -------------------------
@app.get("/")
def root():
    return {"message": "Server is live"}

@app.get("/health")
def health_check():
    try:
        with psycopg.connect(DATABASE_URL) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
        return {"database": "connected"}
    except Exception as e:
        return {"database": "failed", "error": str(e)}

@app.post("/register")
def register(user: RegisterUser):
    hashed_pw = bcrypt.hashpw(user.password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
    try:
        with psycopg.connect(DATABASE_URL) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO users (
                        username, email, password, first_name, middle_name,
                        last_name, age, sex, height_ft, height_in,
                        weight_lb, experience_level, journey_started
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING user_id
                """, (
                    user.username, user.email, hashed_pw, user.first_name,
                    user.middle_name, user.last_name, user.age, user.sex,
                    user.height_ft, user.height_in, user.weight_lb,
                    user.experience_level, user.journey_started
                ))
                user_id = cur.fetchone()[0]
                conn.commit()
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    return {"message": "User registered", "user_id": user_id}

@app.post("/login")
def login(credentials: LoginUser):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
            cur.execute("SELECT * FROM users WHERE email = %s OR username = %s", (credentials.identifier, credentials.identifier))
            user = cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="No account found with that email or username")
            if not bcrypt.checkpw(credentials.password.encode("utf-8"), user["password"].encode("utf-8")):
                raise HTTPException(status_code=401, detail="Invalid password")
    
    return {"message": "Login successful", "user": {k: v for k, v in user.items() if k != "password"}}
#****************************
#Machine Learning Route
#****************************

class LogMLPrediction(BaseModel):
    user_id: int
    exercise_name: str
    predicted_performance: str
    recommended_adjustment: str

@app.post("/ml/predictions")
def log_ml_prediction(data: LogMLPrediction):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            # Look up exercise_id by name
            cur.execute("""
                SELECT exercise_id FROM exercises WHERE exercise_name = %s
            """, (data.exercise_name,))
            result = cur.fetchone()
            if not result:
                raise HTTPException(status_code=404, detail="Exercise not found")
            exercise_id = result[0]

            cur.execute("""
                INSERT INTO ml_prediction 
                    (user_id, exercise_id, date_generated, predicted_performance, recommended_adjustment)
                VALUES (%s, %s, NOW(), %s, %s)
                RETURNING prediction_id
            """, (data.user_id, exercise_id, data.predicted_performance, data.recommended_adjustment))
            prediction_id = cur.fetchone()[0]
            conn.commit()
    return {"prediction_id": prediction_id}

@app.get("/ml/predictions/{user_id}/{exercise_name}")
def get_ml_predictions(user_id: int, exercise_name: str):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
            cur.execute("""
                SELECT mp.*, e.exercise_name
                FROM ml_prediction mp
                JOIN exercises e ON mp.exercise_id = e.exercise_id
                WHERE mp.user_id = %s AND e.exercise_name = %s
                ORDER BY mp.date_generated DESC
            """, (user_id, exercise_name))
            predictions = cur.fetchall()
    return {"predictions": predictions}


class LogAutoAdjustment(BaseModel):
    session_exercise_id: int
    old_weight_lb: float
    new_weight_lb: float
    old_reps: int
    new_reps: int
    reason: str

@app.post("/autoadjustments")
def log_auto_adjustment(data: LogAutoAdjustment):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO autoadjustments 
                    (session_exercise_id, old_weight_lb, new_weight_lb, 
                     old_reps, new_reps, reason, date_applied)
                VALUES (%s, %s, %s, %s, %s, %s, NOW())
                RETURNING adjustment_id
            """, (
                data.session_exercise_id,
                data.old_weight_lb,
                data.new_weight_lb,
                data.old_reps,
                data.new_reps,
                data.reason
            ))
            adjustment_id = cur.fetchone()[0]
            conn.commit()
    return {"adjustment_id": adjustment_id}

@app.get("/autoadjustments/{session_exercise_id}")
def get_auto_adjustments(session_exercise_id: int):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
            cur.execute("""
                SELECT * FROM autoadjustments 
                WHERE session_exercise_id = %s
                ORDER BY date_applied DESC
            """, (session_exercise_id,))
            adjustments = cur.fetchall()
    return {"adjustments": adjustments}


#****************************
#Exercise API route
#****************************


@app.post("/seed-exercises")
async def seed_exercises():
    muscles = [
        "abdominals", "abductors", "adductors", "biceps", "calves",
        "chest", "forearms", "glutes", "hamstrings", "lats",
        "lower_back", "middle_back", "neck", "quadriceps", "traps", "triceps"
    ]
    
    inserted = 0
    
    async with httpx.AsyncClient() as client:
        for muscle in muscles:
            response = await client.get(
                f"https://api.api-ninjas.com/v1/exercises?muscle={muscle}&limit=20",
                headers={"X-Api-Key": NINJA_API_KEY}
            )
            exercises = response.json()
            
            with psycopg.connect(DATABASE_URL) as conn:
                with conn.cursor() as cur:
                    for ex in exercises:
                        cur.execute("""
                            INSERT INTO exercises (exercise_name, muscle_group, type, difficulty, equipment)
                            VALUES (%s, %s, %s, %s, %s)
                            ON CONFLICT (exercise_name) DO NOTHING
                        """, (
                            ex.get("name"),
                            ex.get("muscle"),
                            ex.get("type"),
                            ex.get("difficulty"),
                            ", ".join(ex.get("equipments", []))
                        ))
                        inserted += 1
                    conn.commit()
    
    return {"message": "Exercises seeded", "total_inserted": inserted}


@app.get("/exercises")
def get_exercises(muscle: str = None, difficulty: str = None):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
            if muscle and difficulty:
                cur.execute("SELECT * FROM exercises WHERE muscle_group = %s AND difficulty = %s", (muscle, difficulty))
            elif muscle:
                cur.execute("SELECT * FROM exercises WHERE muscle_group = %s", (muscle,))
            elif difficulty:
                cur.execute("SELECT * FROM exercises WHERE difficulty = %s", (difficulty,))
            else:
                cur.execute("SELECT * FROM exercises")
            exercises = cur.fetchall()
    return {"exercises": exercises}

# ***************************
# Workout Plan Routes
# ***************************

@app.post("/plans")
def create_plan(plan: CreatePlan):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            # Deactivate any existing active plans for this user
            cur.execute("""
                UPDATE workoutplan SET active_flag = false 
                WHERE user_id = %s
            """, (plan.user_id,))
            
            # Create new plan
            cur.execute("""
                INSERT INTO workoutplan (user_id, plan_name, active_flag, last_used_date)
                VALUES (%s, %s, true, %s)
                RETURNING plan_id
            """, (plan.user_id, plan.plan_name, date.today()))
            plan_id = cur.fetchone()[0]
            conn.commit()
    return {"plan_id": plan_id, "plan_name": plan.plan_name}

@app.get("/plans/{user_id}")
def get_plans(user_id: int):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
            cur.execute("""
                SELECT * FROM workoutplan WHERE user_id = %s ORDER BY active_flag DESC
            """, (user_id,))
            plans = cur.fetchall()
    return {"plans": plans}

@app.get("/plans/{plan_id}/exercises")
def get_plan_exercises(plan_id: int):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
            cur.execute("""
                SELECT se.session_exercise_id, se.plan_id, se.target_sets, 
                       se.target_reps, se.notes, e.exercise_name, e.muscle_group,
                       e.difficulty, e.equipment
                FROM sessionexercise se
                JOIN exercises e ON se.exercise_id = e.exercise_id
                WHERE se.plan_id = %s AND se.session_id IS NULL
            """, (plan_id,))
            exercises = cur.fetchall()
    return {"exercises": exercises}

@app.post("/plans/exercises")
def add_exercise_to_plan(data: AddPlanExercise):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            # Look up exercise_id by name
            cur.execute("""
                SELECT exercise_id FROM exercises WHERE exercise_name = %s
            """, (data.exercise_name,))
            result = cur.fetchone()
            if not result:
                raise HTTPException(status_code=404, detail="Exercise not found")
            exercise_id = result[0]

            # Add to plan
            cur.execute("""
                INSERT INTO sessionexercise (plan_id, exercise_id, target_sets, target_reps, notes)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING session_exercise_id
            """, (data.plan_id, exercise_id, data.target_sets, data.target_reps, data.notes))
            session_exercise_id = cur.fetchone()[0]
            conn.commit()
    return {"session_exercise_id": session_exercise_id}

@app.delete("/plans/exercises/{session_exercise_id}")
def remove_exercise_from_plan(session_exercise_id: int):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                DELETE FROM sessionexercise WHERE session_exercise_id = %s
            """, (session_exercise_id,))
            conn.commit()
    return {"message": "Exercise removed from plan"}


# *************************
# Workout Session Routes
# *************************

@app.post("/sessions")
def log_session(data: LogSession):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            # Create the session
            cur.execute("""
                INSERT INTO workoutsession (user_id, plan_id, session_date, duration_minutes, start_workout_flag, workout_miss_flag)
                VALUES (%s, %s, %s, %s, true, %s)
                RETURNING session_id
            """, (data.user_id, data.plan_id, data.session_date, data.duration_minutes, data.missed))
            session_id = cur.fetchone()[0]

            # Update last used date on plan
            cur.execute("""
                UPDATE workoutplan SET last_used_date = %s WHERE plan_id = %s
            """, (date.today(), data.plan_id))

            # Copy plan exercises into session exercises
            cur.execute("""
                INSERT INTO sessionexercise (session_id, plan_id, exercise_id, target_sets, target_reps, notes)
                SELECT %s, plan_id, exercise_id, target_sets, target_reps, notes
                FROM sessionexercise
                WHERE plan_id = %s AND session_id IS NULL
            """, (session_id, data.plan_id))

            conn.commit()
    return {"session_id": session_id}

@app.get("/sessions/{user_id}")
def get_sessions(user_id: int):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
            cur.execute("""
                SELECT ws.*, wp.plan_name
                FROM workoutsession ws
                JOIN workoutplan wp ON ws.plan_id = wp.plan_id
                WHERE ws.user_id = %s
                ORDER BY ws.session_date DESC
            """, (user_id,))
            sessions = cur.fetchall()
    return {"sessions": sessions}

@app.get("/sets/{session_id}")
def get_sets(session_id: int):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
            cur.execute("""
                SELECT ws.*, e.exercise_name, e.muscle_group
                FROM workoutsets ws
                JOIN exercises e ON ws.exercise_id = e.exercise_id
                WHERE ws.workout_session_id = %s
                ORDER BY ws.exercise_id, ws.set_number
            """, (session_id,))
            sets = cur.fetchall()
    return {"sets": sets}

@app.get("/plans/{user_id}/active")
def get_active_plan(user_id: int):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
            cur.execute("""
                SELECT * FROM workoutplan
                WHERE user_id = %s AND active_flag = true
                LIMIT 1
            """, (user_id,))
            plan = cur.fetchone()
    if not plan:
        raise HTTPException(status_code=404, detail="No active plan found")
    return {"plan": plan}

@app.post("/sets")
def log_set(data: LogSet):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            # Look up exercise_id by name
            cur.execute("""
                SELECT exercise_id FROM exercises WHERE exercise_name = %s
            """, (data.exercise_name,))
            result = cur.fetchone()
            if not result:
                raise HTTPException(status_code=404, detail="Exercise not found")
            exercise_id = result[0]

            # Log the set
            cur.execute("""
                INSERT INTO workoutsets (workout_session_id, exercise_id, set_number, weight_lb, reps, rpe)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING set_id
            """, (data.session_id, exercise_id, data.set_number, data.weight_lb, data.reps, data.rpe))
            set_id = cur.fetchone()[0]

            # Find the session_exercise_id for this session and exercise
            cur.execute("""
                SELECT session_exercise_id FROM sessionexercise
                WHERE session_id = %s AND exercise_id = %s
            """, (data.session_id, exercise_id))
            se_result = cur.fetchone()

            # Log performance if session exercise exists
            if se_result:
                session_exercise_id = se_result[0]
                cur.execute("""
                    INSERT INTO exerciseperformance 
                        (session_exercise_id, set_number, completed_flag, actual_reps, actual_weight_lbs)
                    VALUES (%s, %s, %s, %s, %s)
                """, (session_exercise_id, data.set_number, True, data.reps, data.weight_lb))

            conn.commit()
    return {"set_id": set_id}


# *************************
# Nutrition Routes
# *************************

class LogNutrition(BaseModel):
    user_id: int
    log_date: str  # "YYYY-MM-DD"
    calories: float
    protein_g: float
    carbs_g: float
    fats_g: float
    notes: Optional[str] = None

class LogFoodEntry(BaseModel):
    user_id: int
    log_date: str
    food_name: str
    brand: Optional[str] = ""
    calories: float
    protein_g: float
    carbs_g: float
    fats_g: float
    serving_size: Optional[str] = "1 serving"
    quantity: float = 1.0

@app.post("/nutrition/log")
def upsert_nutrition_log(data: LogNutrition):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO nutrition_logs (user_id, log_date, calories, protein_g, carbs_g, fats_g, notes)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (user_id, log_date) DO UPDATE SET
                    calories = EXCLUDED.calories,
                    protein_g = EXCLUDED.protein_g,
                    carbs_g = EXCLUDED.carbs_g,
                    fats_g = EXCLUDED.fats_g,
                    notes = EXCLUDED.notes
            """, (data.user_id, data.log_date, data.calories, data.protein_g,
                  data.carbs_g, data.fats_g, data.notes))
            conn.commit()
    return {"message": "Nutrition log saved"}

@app.get("/nutrition/{user_id}")
def get_nutrition_logs(user_id: int):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
            cur.execute("""
                SELECT * FROM nutrition_logs WHERE user_id = %s ORDER BY log_date DESC
            """, (user_id,))
            logs = cur.fetchall()
    return {"logs": logs}


@app.get("/performance/{user_id}/{exercise_name}")
def get_exercise_performance(user_id: int, exercise_name: str):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
            cur.execute("""
                SELECT ep.set_number, ep.actual_reps, ep.actual_weight_lbs,
                       ep.completed_flag, ws.session_date, e.exercise_name
                FROM exerciseperformance ep
                JOIN sessionexercise se ON ep.session_exercise_id = se.session_exercise_id
                JOIN workoutsession ws ON se.session_id = ws.session_id
                JOIN exercises e ON se.exercise_id = e.exercise_id
                WHERE ws.user_id = %s AND e.exercise_name = %s
                ORDER BY ws.session_date DESC
            """, (user_id, exercise_name))
            records = cur.fetchall()
    return {"performance": records}


@app.post("/nutrition/entries")
def log_food_entry(data: LogFoodEntry):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO nutrition_entries
                    (user_id, log_date, food_name, brand, calories, protein_g, carbs_g, fats_g, serving_size, quantity)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING entry_id
            """, (data.user_id, data.log_date, data.food_name, data.brand,
                  data.calories, data.protein_g, data.carbs_g, data.fats_g,
                  data.serving_size, data.quantity))
            entry_id = cur.fetchone()[0]
            conn.commit()
    return {"entry_id": entry_id}

@app.get("/nutrition/entries/{user_id}/{log_date}")
def get_food_entries(user_id: int, log_date: str):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
            cur.execute("""
                SELECT * FROM nutrition_entries
                WHERE user_id = %s AND log_date = %s
                ORDER BY logged_at
            """, (user_id, log_date))
            entries = cur.fetchall()
    return {"entries": entries}

@app.delete("/nutrition/entries/{entry_id}")
def delete_food_entry(entry_id: int):
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM nutrition_entries WHERE entry_id = %s", (entry_id,))
            conn.commit()
    return {"message": "Entry deleted"}


# ── Nutrition Search ───────────────────────────────────────────────────────────

@app.get("/nutrition/search")
async def nutrition_search(q: str):
    if not NINJA_API_KEY:
        raise HTTPException(status_code=503, detail="Nutrition API not configured")
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://api.api-ninjas.com/v1/nutrition",
            params={"query": q},
            headers={"X-Api-Key": NINJA_API_KEY},
            timeout=10.0
        )
    if resp.status_code != 200:
        return {"items": []}
    return {"items": resp.json()}


# ── Password Reset ─────────────────────────────────────────────────────────────

class ForgotPasswordRequest(BaseModel):
    email: str

class ResetPasswordRequest(BaseModel):
    email: str
    code: str
    new_password: str

def _send_reset_email(to_email: str, code: str) -> bool:
    if not GMAIL_USER or not GMAIL_APP_PASSWORD:
        return False
    try:
        msg = MIMEText(
            f"Your Kinetiq password reset code is:\n\n"
            f"    {code}\n\n"
            f"This code expires in 15 minutes.\n\n"
            f"If you didn't request this, you can safely ignore this email."
        )
        msg["Subject"] = "Kinetiq — Password Reset Code"
        msg["From"] = GMAIL_USER
        msg["To"] = to_email
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(GMAIL_USER, GMAIL_APP_PASSWORD)
            server.sendmail(GMAIL_USER, [to_email], msg.as_string())
        return True
    except Exception as e:
        print(f"[warn] Failed to send reset email to {to_email}: {e}")
        return False

@app.post("/forgot-password")
def forgot_password(data: ForgotPasswordRequest):
    email = data.email.strip().lower()
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT user_id FROM users WHERE email = %s", (email,))
            if not cur.fetchone():
                # Always return success to not expose whether email is registered
                return {"message": "If that email is registered, a code was sent."}
            code = str(secrets.randbelow(900000) + 100000)
            cur.execute("""
                INSERT INTO password_reset_codes (email, code, expires_at)
                VALUES (%s, %s, NOW() + INTERVAL '15 minutes')
                ON CONFLICT (email) DO UPDATE
                    SET code = EXCLUDED.code, expires_at = EXCLUDED.expires_at
            """, (email, code))
            conn.commit()
    _send_reset_email(email, code)
    return {"message": "If that email is registered, a code was sent."}

@app.post("/reset-password")
def reset_password(data: ResetPasswordRequest):
    email = data.email.strip().lower()
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT code FROM password_reset_codes
                WHERE email = %s AND expires_at > NOW()
            """, (email,))
            row = cur.fetchone()
            if not row or row[0] != data.code:
                raise HTTPException(status_code=400, detail="Invalid or expired code.")
            hashed = bcrypt.hashpw(data.new_password.encode(), bcrypt.gensalt()).decode()
            cur.execute("UPDATE users SET password_hash = %s WHERE email = %s", (hashed, email))
            cur.execute("DELETE FROM password_reset_codes WHERE email = %s", (email,))
            conn.commit()
    return {"message": "Password reset successfully."}
