import express, { Request, Response } from "express";
import Database from "better-sqlite3";

const app = express();
const PORT = 8080;

app.use(express.json());

// Initialize SQLite database
const db = new Database("todos.db");
db.pragma("journal_mode = WAL");

// Create table if it does not exist
db.exec(`
  CREATE TABLE IF NOT EXISTS todos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
`);

// Helper: convert a raw row from SQLite into the API response shape
interface TodoRow {
  id: number;
  title: string;
  completed: number;
  created_at: string;
}

interface TodoResponse {
  id: number;
  title: string;
  completed: boolean;
  created_at: string;
}

function formatTodo(row: TodoRow): TodoResponse {
  return {
    id: row.id,
    title: row.title,
    completed: row.completed === 1,
    created_at: row.created_at,
  };
}

// GET /todos - List all todos
app.get("/todos", (_req: Request, res: Response) => {
  const rows = db.prepare("SELECT * FROM todos").all() as TodoRow[];
  res.json(rows.map(formatTodo));
});

// POST /todos - Create a new todo
app.post("/todos", (req: Request, res: Response) => {
  const { title } = req.body;

  if (!title || typeof title !== "string") {
    res.status(400).json({ error: "title is required" });
    return;
  }

  const createdAt = new Date().toISOString();
  const stmt = db.prepare(
    "INSERT INTO todos (title, completed, created_at) VALUES (?, 0, ?)"
  );
  const result = stmt.run(title, createdAt);

  const todo = db
    .prepare("SELECT * FROM todos WHERE id = ?")
    .get(result.lastInsertRowid) as TodoRow;

  res.status(201).json(formatTodo(todo));
});

// PUT /todos/:id - Update an existing todo
app.put("/todos/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const existing = db
    .prepare("SELECT * FROM todos WHERE id = ?")
    .get(id) as TodoRow | undefined;

  if (!existing) {
    res.status(404).json({ error: "not found" });
    return;
  }

  const title =
    req.body.title !== undefined ? req.body.title : existing.title;
  const completed =
    req.body.completed !== undefined
      ? req.body.completed
        ? 1
        : 0
      : existing.completed;

  db.prepare("UPDATE todos SET title = ?, completed = ? WHERE id = ?").run(
    title,
    completed,
    id
  );

  const updated = db
    .prepare("SELECT * FROM todos WHERE id = ?")
    .get(id) as TodoRow;

  res.json(formatTodo(updated));
});

// DELETE /todos/:id - Delete a todo
app.delete("/todos/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const existing = db
    .prepare("SELECT * FROM todos WHERE id = ?")
    .get(id) as TodoRow | undefined;

  if (!existing) {
    res.status(404).json({ error: "not found" });
    return;
  }

  db.prepare("DELETE FROM todos WHERE id = ?").run(id);
  res.json({ message: "deleted" });
});

// Start server
app.listen(PORT, () => {
  console.log(`Todo API server running on http://localhost:${PORT}`);
});
