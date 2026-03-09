import express from 'express';
import Database from 'better-sqlite3';

const app = express();
const router = express.Router();
const PORT = 8080;

app.use(express.json());

const db = new Database('todos.db');
db.exec(`
  CREATE TABLE IF NOT EXISTS todos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT (datetime('now', 'utc'))
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

const getAllTodos = db.prepare('SELECT * FROM todos ORDER BY id');
const getTodoById = db.prepare('SELECT * FROM todos WHERE id = ?');
const insertTodo = db.prepare('INSERT INTO todos (title) VALUES (?)');
const updateTodo = db.prepare('UPDATE todos SET title = ?, completed = ? WHERE id = ?');
const deleteTodoById = db.prepare('DELETE FROM todos WHERE id = ?');

router.get('/todos', (_req, res) => {
  const rows = getAllTodos.all() as TodoRow[];
  res.json(rows.map(formatTodo));
});

router.post('/todos', (req, res) => {
  const { title } = req.body;
  if (typeof title !== 'string' || title.trim() === '') {
    return res.status(400).json({ error: 'title is required' });
  }
  const result = insertTodo.run(title.trim());
  const row = getTodoById.get(result.lastInsertRowid) as TodoRow;
  res.status(201).json(formatTodo(row));
});

router.put('/todos/:id', (req, res) => {
  const id = parseInt(req.params.id, 10);
  const row = getTodoById.get(id) as TodoRow | undefined;
  if (!row) return res.status(404).json({ error: 'Todo not found' });
  const title = req.body.title ?? row.title;
  const completed = req.body.completed !== undefined ? req.body.completed : Boolean(row.completed);
  updateTodo.run(title, completed ? 1 : 0, id);
  const updated = getTodoById.get(id) as TodoRow;
  res.json(formatTodo(updated));
});

router.delete('/todos/:id', (req, res) => {
  const id = parseInt(req.params.id, 10);
  const row = getTodoById.get(id) as TodoRow | undefined;
  if (!row) return res.status(404).json({ error: 'Todo not found' });
  deleteTodoById.run(id);
  res.json({ message: 'deleted' });
});

app.use(router);
app.listen(PORT, () => console.log(`Todo API running on http://localhost:${PORT}`));
