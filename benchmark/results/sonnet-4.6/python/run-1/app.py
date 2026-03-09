from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import aiosqlite
import uvicorn
from typing import Optional

DB_PATH = "todos.db"

@asynccontextmanager
async def lifespan(app: FastAPI):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("""
            CREATE TABLE IF NOT EXISTS todos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                completed BOOLEAN NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
        """)
        await db.commit()
    yield

app = FastAPI(lifespan=lifespan)

class TodoCreate(BaseModel):
    title: str

class TodoUpdate(BaseModel):
    title: Optional[str] = None
    completed: Optional[bool] = None

def row_to_dict(row):
    return {
        "id": row[0],
        "title": row[1],
        "completed": bool(row[2]),
        "created_at": row[3]
    }

@app.get("/todos")
async def get_todos():
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute("SELECT id, title, completed, created_at FROM todos") as cursor:
            rows = await cursor.fetchall()
    return [row_to_dict(r) for r in rows]

@app.post("/todos", status_code=201)
async def create_todo(todo: TodoCreate):
    async with aiosqlite.connect(DB_PATH) as db:
        cursor = await db.execute(
            "INSERT INTO todos (title) VALUES (?)", (todo.title,)
        )
        await db.commit()
        async with db.execute(
            "SELECT id, title, completed, created_at FROM todos WHERE id = ?",
            (cursor.lastrowid,)
        ) as c:
            row = await c.fetchone()
    return row_to_dict(row)

@app.put("/todos/{todo_id}")
async def update_todo(todo_id: int, todo: TodoUpdate):
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute(
            "SELECT id, title, completed, created_at FROM todos WHERE id = ?", (todo_id,)
        ) as cursor:
            existing = await cursor.fetchone()
        if not existing:
            raise HTTPException(status_code=404, detail="Todo not found")
        title = todo.title if todo.title is not None else existing[1]
        completed = todo.completed if todo.completed is not None else bool(existing[2])
        await db.execute(
            "UPDATE todos SET title = ?, completed = ? WHERE id = ?",
            (title, completed, todo_id)
        )
        await db.commit()
        async with db.execute(
            "SELECT id, title, completed, created_at FROM todos WHERE id = ?", (todo_id,)
        ) as c:
            row = await c.fetchone()
    return row_to_dict(row)

@app.delete("/todos/{todo_id}")
async def delete_todo(todo_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute("SELECT id FROM todos WHERE id = ?", (todo_id,)) as cursor:
            existing = await cursor.fetchone()
        if not existing:
            raise HTTPException(status_code=404, detail="Todo not found")
        await db.execute("DELETE FROM todos WHERE id = ?", (todo_id,))
        await db.commit()
    return {"message": "deleted"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
