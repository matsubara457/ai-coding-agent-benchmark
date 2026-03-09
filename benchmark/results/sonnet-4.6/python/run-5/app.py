import aiosqlite
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, Any

app = FastAPI()
DB = "todos.db"

@app.on_event("startup")
async def startup():
    async with aiosqlite.connect(DB) as db:
        await db.execute("""CREATE TABLE IF NOT EXISTS todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            completed INTEGER DEFAULT 0,
            created_at TEXT DEFAULT (datetime('now')))""")
        await db.commit()

async def query(sql: str, params: tuple = (), fetch: str = "none") -> Any:
    async with aiosqlite.connect(DB) as db:
        db.row_factory = aiosqlite.Row
        cur = await db.execute(sql, params)
        await db.commit()
        if fetch == "all":
            return [dict(r) for r in await cur.fetchall()]
        if fetch == "one":
            r = await cur.fetchone()
            return dict(r) if r else None
        return cur.lastrowid

def fmt(r): return {**r, "completed": bool(r["completed"])}

class TC(BaseModel):
    title: str

class TU(BaseModel):
    title: Optional[str] = None
    completed: Optional[bool] = None

@app.get("/todos")
async def index(): return [fmt(r) for r in await query("SELECT * FROM todos", fetch="all")]

@app.post("/todos", status_code=201)
async def create(b: TC):
    rid = await query("INSERT INTO todos (title) VALUES (?)", (b.title,))
    return fmt(await query("SELECT * FROM todos WHERE id=?", (rid,), "one"))

@app.put("/todos/{i}")
async def update(i: int, b: TU):
    e = await query("SELECT * FROM todos WHERE id=?", (i,), "one")
    if not e: raise HTTPException(404, "Not found")
    t = b.title if b.title is not None else e["title"]
    c = b.completed if b.completed is not None else bool(e["completed"])
    await query("UPDATE todos SET title=?,completed=? WHERE id=?", (t, int(c), i))
    return fmt(await query("SELECT * FROM todos WHERE id=?", (i,), "one"))

@app.delete("/todos/{i}")
async def delete(i: int):
    if not await query("SELECT id FROM todos WHERE id=?", (i,), "one"):
        raise HTTPException(404, "Not found")
    await query("DELETE FROM todos WHERE id=?", (i,))
    return {"message": "deleted"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
