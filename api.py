from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from datetime import date
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
    first_name: str
    middle_name: str | None = None
    last_name: str
    age: int
    sex: str
    height_ft: int
    height_in: int
    weight_lb: float
    experience_level: str
    journey_started: date  # format: "YYYY-MM-DD"

class LoginUser(BaseModel):
    email: EmailStr
    password: str

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
                headers={"X-Api-Key": API_KEY}
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
                            ex.get("equipment")
                        ))
                        inserted += 1
                    conn.commit()
    
    return {"message": f"Exercises seeded", "total_inserted": inserted}

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