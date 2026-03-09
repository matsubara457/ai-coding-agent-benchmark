import aiosqlite
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional

DB = "todos.db"
app = FastAPI()

async def db_fetchall(sql: str, params=()):
    async with aiosqlite.connect(DB) as conn:
        conn.row_factory = aiosqlite.Row
        async with conn.execute(sql, params) as cur:
            rows = await cur.fetchall()
        return [dict(r) for r in rows]

async def db_fetchone(sql: str, params=()):
    async with aiosqlite.connect(DB) as conn:
        conn.row_factory = aiosqlite.Row
        async with conn.execute(sql, params) as cur:
            row = await cur.fetchone()
        return dict(row) if row else None

async def db_execute(sql: str, params=()):
    async with aiosqlite.connect(DB) as conn:
        cur = await conn.execute(sql, params)
        await conn.commit()
        return cur.lastrowid

async def setup():
    await db_execute("""
        CREATE TABLE IF NOT EXISTS todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            completed INTEGER DEFAULT 0,
            created_at TEXT DEFAULT (datetime('now'))
        )
    """)

@app.on_event("startup")
async def startup():
    await setup()

def fmt(r: dict) -> dict:
    return {**r, "completed": bool(r["completed"])}

class TodoCreate(BaseModel):
    title: str

class TodoUpdate(BaseModel):
    title: Optional[str] = None
    completed: Optional[bool] = None

@app.get("/todos")
async def get_todos():
    rows = await db_fetchall("SELECT * FROM todos")
    return [fmt(r) for r in rows]

@app.post("/todos", status_code=201)
async def post_todo(body: TodoCreate):
    row_id = await db_execute("INSERT INTO todos (title) VALUES (?)", (body.title,))
    row = await db_fetchone("SELECT * FROM todos WHERE id = ?", (row_id,))
    return fmt(row)

@app.put("/todos/{todo_id}")
async def put_todo(todo_id: int, body: TodoUpdate):
    existing = await db_fetchone("SELECT * FROM todos WHERE id = ?", (todo_id,))
    if not existing:
        raise HTTPException(status_code=404, detail="Not found")
    title = body.title if body.title is not None else existing["title"]
    completed = body.completed if body.completed is not None else bool(existing["completed"])
    await db_execute(
        "UPDATE todos SET title = ?, completed = ? WHERE id = ?",
        (title, int(completed), todo_id)
    )
    row = await db_fetchone("SELECT * FROM todos WHERE id = ?", (todo_id,))
    return fmt(row)

@app.delete("/todos/{todo_id}")
async def delete_todo(todo_id: int):
    existing = await db_fetchone("SELECT id FROM todos WHERE id = ?", (todo_id,))
    if not existing:
        raise HTTPException(status_code=404, detail="Not found")
    await db_execute("DELETE FROM todos WHERE id = ?", (todo_id,))
    return {"message": "deleted"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
