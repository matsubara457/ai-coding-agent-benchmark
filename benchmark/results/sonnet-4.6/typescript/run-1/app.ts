import express, { Request, Response } from 'express';
import Database from 'better-sqlite3';

const app = express();
const PORT = 8080;
app.use(express.json());

const db = new Database('todos.db');
db.exec(`CREATE TABLE IF NOT EXISTS todos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  completed INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
)`);

const toTodo = (row: any) => ({ ...row, completed: Boolean(row.completed) });

app.get('/todos', (_req: Request, res: Response) => {
  const todos = db.prepare('SELECT * FROM todos').all().map(toTodo);
  res.json(todos);
});

app.post('/todos', (req: Request, res: Response) => {
  const { title } = req.body;
  if (!title) return res.status(400).json({ error: 'title required' });
  const info = db.prepare('INSERT INTO todos (title) VALUES (?)').run(title);
  const todo = db.prepare('SELECT * FROM todos WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json(toTodo(todo));
});

app.put('/todos/:id', (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const existing = db.prepare('SELECT * FROM todos WHERE id = ?').get(id) as any;
  if (!existing) return res.status(404).json({ error: 'Not found' });
  const { title = existing.title, completed = Boolean(existing.completed) } = req.body;
  db.prepare('UPDATE todos SET title = ?, completed = ? WHERE id = ?').run(title, completed ? 1 : 0, id);
  const updated = db.prepare('SELECT * FROM todos WHERE id = ?').get(id);
  res.json(toTodo(updated));
});

app.delete('/todos/:id', (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const existing = db.prepare('SELECT id FROM todos WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'Not found' });
  db.prepare('DELETE FROM todos WHERE id = ?').run(id);
  res.json({ message: 'deleted' });
});

app.listen(PORT, () => console.log(`Server on port ${PORT}`));
