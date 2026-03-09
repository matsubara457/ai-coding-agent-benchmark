import sqlite3
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
import asyncio
from concurrent.futures import ThreadPoolExecutor

DB_PATH = "todos.db"
executor = ThreadPoolExecutor()
app = FastAPI()

def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            completed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
    """)
    conn.commit()
    conn.close()

init_db()

def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def _fetch_all():
    conn = get_conn()
    rows = conn.execute("SELECT * FROM todos").fetchall()
    conn.close()
    return [dict(r) for r in rows]

def _insert_todo(title: str):
    conn = get_conn()
    cur = conn.execute("INSERT INTO todos (title) VALUES (?)", (title,))
    conn.commit()
    row = conn.execute("SELECT * FROM todos WHERE id = ?", (cur.lastrowid,)).fetchone()
    conn.close()
    return dict(row)

def _get_todo(todo_id: int):
    conn = get_conn()
    row = conn.execute("SELECT * FROM todos WHERE id = ?", (todo_id,)).fetchone()
    conn.close()
    return dict(row) if row else None

def _update_todo(todo_id: int, title: str, completed: bool):
    conn = get_conn()
    conn.execute("UPDATE todos SET title = ?, completed = ? WHERE id = ?", (title, int(completed), todo_id))
    conn.commit()
    row = conn.execute("SELECT * FROM todos WHERE id = ?", (todo_id,)).fetchone()
    conn.close()
    return dict(row)

def _delete_todo(todo_id: int):
    conn = get_conn()
    conn.execute("DELETE FROM todos WHERE id = ?", (todo_id,))
    conn.commit()
    conn.close()

def fmt(row: dict):
    return {**row, "completed": bool(row["completed"])}

class TodoIn(BaseModel):
    title: str

class TodoPatch(BaseModel):
    title: Optional[str] = None
    completed: Optional[bool] = None

@app.get("/todos")
async def list_todos():
    loop = asyncio.get_event_loop()
    rows = await loop.run_in_executor(executor, _fetch_all)
    return [fmt(r) for r in rows]

@app.post("/todos", status_code=201)
async def create_todo(body: TodoIn):
    loop = asyncio.get_event_loop()
    row = await loop.run_in_executor(executor, _insert_todo, body.title)
    return fmt(row)

@app.put("/todos/{todo_id}")
async def update_todo(todo_id: int, body: TodoPatch):
    loop = asyncio.get_event_loop()
    existing = await loop.run_in_executor(executor, _get_todo, todo_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Not found")
    title = body.title if body.title is not None else existing["title"]
    completed = body.completed if body.completed is not None else bool(existing["completed"])
    row = await loop.run_in_executor(executor, _update_todo, todo_id, title, completed)
    return fmt(row)

@app.delete("/todos/{todo_id}")
async def delete_todo(todo_id: int):
    loop = asyncio.get_event_loop()
    existing = await loop.run_in_executor(executor, _get_todo, todo_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Not found")
    await loop.run_in_executor(executor, _delete_todo, todo_id)
    return {"message": "deleted"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
