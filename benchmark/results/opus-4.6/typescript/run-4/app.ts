import express, { Request, Response } from "express";
import Database from "better-sqlite3";
import path from "path";

const app = express();
const PORT = 8080;

app.use(express.json());

// Initialize SQLite database
const dbPath = path.join(__dirname, "todos.db");
const db = new Database(dbPath);

// Enable WAL mode for better performance
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

// Prepared statements
const selectAll = db.prepare("SELECT * FROM todos");
const selectById = db.prepare("SELECT * FROM todos WHERE id = ?");
const insertTodo = db.prepare("INSERT INTO todos (title) VALUES (?)");
const updateTodo = db.prepare(
  "UPDATE todos SET title = ?, completed = ? WHERE id = ?"
);
const deleteTodo = db.prepare("DELETE FROM todos WHERE id = ?");

// Helper: convert DB row to API response format
interface TodoRow {
  id: number;
  title: string;
  completed: number;
  created_at: string;
}

function formatTodo(row: TodoRow) {
  return {
    id: row.id,
    title: row.title,
    completed: row.completed === 1,
    created_at: row.created_at,
  };
}

// GET /todos - List all todos
app.get("/todos", (_req: Request, res: Response) => {
  const rows = selectAll.all() as TodoRow[];
  res.json(rows.map(formatTodo));
});

// POST /todos - Create a new todo
app.post("/todos", (req: Request, res: Response) => {
  const { title } = req.body;

  if (!title || typeof title !== "string") {
    res.status(400).json({ error: "title is required and must be a string" });
    return;
  }

  const result = insertTodo.run(title);
  const todo = selectById.get(result.lastInsertRowid) as TodoRow;
  res.status(201).json(formatTodo(todo));
});

// PUT /todos/:id - Update a todo
app.put("/todos/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const existing = selectById.get(id) as TodoRow | undefined;

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

  updateTodo.run(title, completed, id);
  const updated = selectById.get(id) as TodoRow;
  res.json(formatTodo(updated));
});

// DELETE /todos/:id - Delete a todo
app.delete("/todos/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const existing = selectById.get(id) as TodoRow | undefined;

  if (!existing) {
    res.status(404).json({ error: "not found" });
    return;
  }

  deleteTodo.run(id);
  res.json({ message: "deleted" });
});

// Start server
app.listen(PORT, () => {
  console.log(`Todo API server running on http://localhost:${PORT}`);
});
