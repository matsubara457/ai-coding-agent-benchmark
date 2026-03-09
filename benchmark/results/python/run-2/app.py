import sqlite3
import os
from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn

app = FastAPI()

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "todos.db")


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
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
    conn.commit()
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
def startup():
    init_db()


@app.get("/todos")
def list_todos():
    conn = get_db()
    try:
        rows = conn.execute("SELECT * FROM todos").fetchall()
        return [row_to_dict(row) for row in rows]
    finally:
        conn.close()


@app.post("/todos", status_code=201)
def create_todo(todo: TodoCreate):
    created_at = datetime.now(timezone.utc).isoformat()
    conn = get_db()
    try:
        cursor = conn.execute(
            "INSERT INTO todos (title, completed, created_at) VALUES (?, ?, ?)",
            (todo.title, False, created_at),
        )
        conn.commit()
        todo_id = cursor.lastrowid
        row = conn.execute("SELECT * FROM todos WHERE id = ?", (todo_id,)).fetchone()
        return row_to_dict(row)
    finally:
        conn.close()


@app.put("/todos/{todo_id}")
def update_todo(todo_id: int, todo: TodoUpdate):
    conn = get_db()
    try:
        existing = conn.execute(
            "SELECT * FROM todos WHERE id = ?", (todo_id,)
        ).fetchone()
        if existing is None:
            raise HTTPException(status_code=404, detail="Todo not found")

        title = todo.title if todo.title is not None else existing["title"]
        completed = todo.completed if todo.completed is not None else bool(existing["completed"])

        conn.execute(
            "UPDATE todos SET title = ?, completed = ? WHERE id = ?",
            (title, completed, todo_id),
        )
        conn.commit()

        row = conn.execute("SELECT * FROM todos WHERE id = ?", (todo_id,)).fetchone()
        return row_to_dict(row)
    finally:
        conn.close()


@app.delete("/todos/{todo_id}")
def delete_todo(todo_id: int):
    conn = get_db()
    try:
        existing = conn.execute(
            "SELECT * FROM todos WHERE id = ?", (todo_id,)
        ).fetchone()
        if existing is None:
            raise HTTPException(status_code=404, detail="Todo not found")

        conn.execute("DELETE FROM todos WHERE id = ?", (todo_id,))
        conn.commit()
        return {"message": "deleted"}
    finally:
        conn.close()


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
