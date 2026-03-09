import express, { Request, Response } from "express";
import Database from "better-sqlite3";

const app = express();
app.use(express.json());

const db = new Database("todos.db");
db.pragma("journal_mode = WAL");

db.exec(`
  CREATE TABLE IF NOT EXISTS todos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
  )
`);

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

// GET /todos - list all todos
app.get("/todos", (_req: Request, res: Response) => {
  const rows = db.prepare("SELECT * FROM todos").all() as TodoRow[];
  res.json(rows.map(formatTodo));
});

// POST /todos - create a new todo
app.post("/todos", (req: Request, res: Response) => {
  const { title } = req.body;
  if (!title) {
    res.status(400).json({ error: "title is required" });
    return;
  }

  const stmt = db.prepare(
    "INSERT INTO todos (title) VALUES (?)"
  );
  const result = stmt.run(title);

  const todo = db
    .prepare("SELECT * FROM todos WHERE id = ?")
    .get(result.lastInsertRowid) as TodoRow;

  res.status(201).json(formatTodo(todo));
});

// PUT /todos/:id - update a todo
app.put("/todos/:id", (req: Request, res: Response) => {
  const id = parseInt(req.params.id, 10);

  const existing = db
    .prepare("SELECT * FROM todos WHERE id = ?")
    .get(id) as TodoRow | undefined;

  if (!existing) {
    res.status(404).json({ error: "not found" });
    return;
  }

  const title = req.body.title !== undefined ? req.body.title : existing.title;
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

// DELETE /todos/:id - delete a todo
app.delete("/todos/:id", (req: Request, res: Response) => {
  const id = parseInt(req.params.id, 10);

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

app.listen(8080, () => {
  console.log("Server running on port 8080");
});
