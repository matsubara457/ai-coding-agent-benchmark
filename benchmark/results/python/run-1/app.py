"""Todo REST API - FastAPI + aiosqlite implementation."""

import aiosqlite
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn

DATABASE = "todos.db"


async def init_db():
    async with aiosqlite.connect(DATABASE) as db:
        await db.execute(
            """
            CREATE TABLE IF NOT EXISTS todos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                completed BOOLEAN NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL
            )
            """
        )
        await db.commit()


def row_to_dict(row) -> dict:
    return {
        "id": row[0],
        "title": row[1],
        "completed": bool(row[2]),
        "created_at": row[3],
    }


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


app = FastAPI(lifespan=lifespan)


class TodoCreate(BaseModel):
    title: str


class TodoUpdate(BaseModel):
    title: Optional[str] = None
    completed: Optional[bool] = None


@app.get("/todos")
async def list_todos():
    async with aiosqlite.connect(DATABASE) as db:
        cursor = await db.execute("SELECT id, title, completed, created_at FROM todos")
        rows = await cursor.fetchall()
    return [row_to_dict(row) for row in rows]


@app.post("/todos")
async def create_todo(todo: TodoCreate):
    created_at = datetime.now(timezone.utc).isoformat()
    async with aiosqlite.connect(DATABASE) as db:
        cursor = await db.execute(
            "INSERT INTO todos (title, completed, created_at) VALUES (?, ?, ?)",
            (todo.title, False, created_at),
        )
        await db.commit()
        todo_id = cursor.lastrowid
    return JSONResponse(
        status_code=201,
        content={
            "id": todo_id,
            "title": todo.title,
            "completed": False,
            "created_at": created_at,
        },
    )


@app.put("/todos/{todo_id}")
async def update_todo(todo_id: int, todo: TodoUpdate):
    async with aiosqlite.connect(DATABASE) as db:
        cursor = await db.execute(
            "SELECT id, title, completed, created_at FROM todos WHERE id = ?",
            (todo_id,),
        )
        row = await cursor.fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Todo not found")

        existing = row_to_dict(row)
        new_title = todo.title if todo.title is not None else existing["title"]
        new_completed = todo.completed if todo.completed is not None else existing["completed"]

        await db.execute(
            "UPDATE todos SET title = ?, completed = ? WHERE id = ?",
            (new_title, new_completed, todo_id),
        )
        await db.commit()

    return {
        "id": todo_id,
        "title": new_title,
        "completed": new_completed,
        "created_at": existing["created_at"],
    }


@app.delete("/todos/{todo_id}")
async def delete_todo(todo_id: int):
    async with aiosqlite.connect(DATABASE) as db:
        cursor = await db.execute(
            "SELECT id FROM todos WHERE id = ?",
            (todo_id,),
        )
        row = await cursor.fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Todo not found")

        await db.execute("DELETE FROM todos WHERE id = ?", (todo_id,))
        await db.commit()

    return {"message": "deleted"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
