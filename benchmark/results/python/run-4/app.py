import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional

import uvicorn

DB_NAME = "todos.db"

app = FastAPI()


def init_db():
    with get_db() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS todos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                completed BOOLEAN NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL
            )
            """
        )


@contextmanager
def get_db():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def row_to_dict(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "title": row["title"],
        "completed": bool(row["completed"]),
        "created_at": row["created_at"],
    }


class TodoCreate(BaseModel):
    title: str


class TodoUpdate(BaseModel):
    title: Optional[str] = None
    completed: Optional[bool] = None


@app.on_event("startup")
def on_startup():
    init_db()


@app.get("/todos")
def list_todos():
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM todos").fetchall()
    return [row_to_dict(r) for r in rows]


@app.post("/todos", status_code=201)
def create_todo(body: TodoCreate):
    created_at = datetime.now(timezone.utc).isoformat()
    with get_db() as conn:
        cursor = conn.execute(
            "INSERT INTO todos (title, completed, created_at) VALUES (?, ?, ?)",
            (body.title, False, created_at),
        )
        todo_id = cursor.lastrowid
        row = conn.execute("SELECT * FROM todos WHERE id = ?", (todo_id,)).fetchone()
    return row_to_dict(row)


@app.put("/todos/{todo_id}")
def update_todo(todo_id: int, body: TodoUpdate):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM todos WHERE id = ?", (todo_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Todo not found")

        new_title = body.title if body.title is not None else row["title"]
        new_completed = body.completed if body.completed is not None else bool(row["completed"])

        conn.execute(
            "UPDATE todos SET title = ?, completed = ? WHERE id = ?",
            (new_title, new_completed, todo_id),
        )
        updated = conn.execute("SELECT * FROM todos WHERE id = ?", (todo_id,)).fetchone()
    return row_to_dict(updated)


@app.delete("/todos/{todo_id}")
def delete_todo(todo_id: int):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM todos WHERE id = ?", (todo_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Todo not found")
        conn.execute("DELETE FROM todos WHERE id = ?", (todo_id,))
    return {"message": "deleted"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
