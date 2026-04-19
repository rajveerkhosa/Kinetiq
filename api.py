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
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "").replace("postgres://", "postgresql://", 1)
NINJA_API_KEY = os.getenv("API_KEY")
app = FastAPI()

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

class LoginUser(BaseModel):
    email: EmailStr
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
            cur.execute("SELECT * FROM users WHERE email = %s", (credentials.email,))
            user = cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="User not found")
            if not bcrypt.checkpw(credentials.password.encode("utf-8"), user["password"].encode("utf-8")):
                raise HTTPException(status_code=401, detail="Invalid password")
    
    return {"message": "Login successful", "user": {k: v for k, v in user.items() if k != "password"}}
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
            cur.execute("""
                INSERT INTO workoutsession (user_id, plan_id, session_date, start_workout_flag, workout_miss_flag)
                VALUES (%s, %s, %s, true, %s)
                RETURNING session_id
            """, (data.user_id, data.plan_id, data.session_date, data.missed))
            session_id = cur.fetchone()[0]

            # Update last used date on plan
            cur.execute("""
                UPDATE workoutplan SET last_used_date = %s WHERE plan_id = %s
            """, (date.today(), data.plan_id))
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

            cur.execute("""
                INSERT INTO workoutsets (workout_session_id, exercise_id, set_number, weight_lb, reps)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING set_id
            """, (data.session_id, exercise_id, data.set_number, data.weight_lb, data.reps))
            set_id = cur.fetchone()[0]
            conn.commit()
    return {"set_id": set_id}

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


