from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import psycopg
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "").replace("postgres://", "postgresql://", 1)

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Basic check — is the server alive?
@app.get("/")
def root():
    return {"message": "Server is live "}

# DB check — is the database connected?
@app.get("/health")
def health_check():
    try:
        with psycopg.connect(DATABASE_URL) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
        return {"database": "connected"}
    except Exception as e:
        return {"database": "failed ", "error": str(e)}