import sqlite3
from flask import Flask, request, jsonify

app = Flask(__name__)
DB_PATH = "todos.db"

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    with get_db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS todos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                completed INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
        """)
        conn.commit()

init_db()

def fmt(row):
    d = dict(row)
    d["completed"] = bool(d["completed"])
    return d

@app.get("/todos")
def list_todos():
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM todos").fetchall()
    return jsonify([fmt(r) for r in rows])

@app.post("/todos")
def create_todo():
    data = request.get_json()
    title = data.get("title") if data else None
    if not title:
        return jsonify({"error": "title required"}), 400
    with get_db() as conn:
        cur = conn.execute("INSERT INTO todos (title) VALUES (?)", (title,))
        conn.commit()
        row = conn.execute("SELECT * FROM todos WHERE id = ?", (cur.lastrowid,)).fetchone()
    return jsonify(fmt(row)), 201

@app.put("/todos/<int:todo_id>")
def update_todo(todo_id: int):
    with get_db() as conn:
        existing = conn.execute("SELECT * FROM todos WHERE id = ?", (todo_id,)).fetchone()
        if not existing:
            return jsonify({"error": "Not found"}), 404
        data = request.get_json() or {}
        title = data.get("title", existing["title"])
        completed = data.get("completed", bool(existing["completed"]))
        conn.execute(
            "UPDATE todos SET title = ?, completed = ? WHERE id = ?",
            (title, int(completed), todo_id)
        )
        conn.commit()
        row = conn.execute("SELECT * FROM todos WHERE id = ?", (todo_id,)).fetchone()
    return jsonify(fmt(row))

@app.delete("/todos/<int:todo_id>")
def delete_todo(todo_id: int):
    with get_db() as conn:
        existing = conn.execute("SELECT id FROM todos WHERE id = ?", (todo_id,)).fetchone()
        if not existing:
            return jsonify({"error": "Not found"}), 404
        conn.execute("DELETE FROM todos WHERE id = ?", (todo_id,))
        conn.commit()
    return jsonify({"message": "deleted"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
