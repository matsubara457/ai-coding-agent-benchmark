import express, { Request, Response } from "express";
import Database from "better-sqlite3";
import path from "path";

// --- Database setup ---

const dbPath = path.join(__dirname, "todos.db");
const db = new Database(dbPath);

// Enable WAL mode for better concurrency
db.pragma("journal_mode = WAL");

db.exec(`
  CREATE TABLE IF NOT EXISTS todos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
`);

// --- Helpers ---

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

function rowToTodo(row: TodoRow): TodoResponse {
  return {
    id: row.id,
    title: row.title,
    completed: row.completed === 1,
    created_at: row.created_at,
  };
}

// --- Prepared statements ---

const stmtSelectAll = db.prepare("SELECT * FROM todos");
const stmtSelectById = db.prepare("SELECT * FROM todos WHERE id = ?");
const stmtInsert = db.prepare(
  "INSERT INTO todos (title, completed, created_at) VALUES (?, 0, ?)"
);
const stmtUpdate = db.prepare(
  "UPDATE todos SET title = ?, completed = ? WHERE id = ?"
);
const stmtDelete = db.prepare("DELETE FROM todos WHERE id = ?");

// --- Express app ---

const app = express();
app.use(express.json());

// GET /todos - return all todos
app.get("/todos", (_req: Request, res: Response) => {
  const rows = stmtSelectAll.all() as TodoRow[];
  const todos = rows.map(rowToTodo);
  res.json(todos);
});

// POST /todos - create a new todo
app.post("/todos", (req: Request, res: Response) => {
  const { title } = req.body;

  if (!title || typeof title !== "string") {
    res.status(400).json({ error: "title is required" });
    return;
  }

  const createdAt = new Date().toISOString();
  const result = stmtInsert.run(title, createdAt);

  const row = stmtSelectById.get(result.lastInsertRowid) as TodoRow;
  res.status(201).json(rowToTodo(row));
});

// PUT /todos/:id - update a todo
app.put("/todos/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);

  const existing = stmtSelectById.get(id) as TodoRow | undefined;
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

  stmtUpdate.run(title, completed, id);

  const updated = stmtSelectById.get(id) as TodoRow;
  res.json(rowToTodo(updated));
});

// DELETE /todos/:id - delete a todo
app.delete("/todos/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);

  const existing = stmtSelectById.get(id) as TodoRow | undefined;
  if (!existing) {
    res.status(404).json({ error: "not found" });
    return;
  }

  stmtDelete.run(id);
  res.json({ message: "deleted" });
});

// --- Start server ---

const PORT = 8080;
app.listen(PORT, () => {
  console.log(`Todo API server running on http://localhost:${PORT}`);
});
