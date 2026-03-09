import express from 'express';
import Database from 'better-sqlite3';

const app = express();
app.use(express.json());

const db = new Database('todos.db');
db.exec('CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, completed INTEGER DEFAULT 0, created_at TEXT DEFAULT (datetime(\'now\')))');

const fmt = (r: any) => ({ id: r.id, title: r.title, completed: Boolean(r.completed), created_at: r.created_at });
const find = (id: number) => db.prepare('SELECT * FROM todos WHERE id = ?').get(id) as any;

app.get('/todos', (_, res) => res.json(db.prepare('SELECT * FROM todos').all().map(fmt)));

app.post('/todos', (req, res) => {
  const { title } = req.body;
  if (!title) return res.status(400).json({ error: 'title required' });
  const { lastInsertRowid } = db.prepare('INSERT INTO todos (title) VALUES (?)').run(title);
  res.status(201).json(fmt(find(Number(lastInsertRowid))));
});

app.put('/todos/:id', (req, res) => {
  const id = Number(req.params.id);
  const row = find(id);
  if (!row) return res.status(404).json({ error: 'Not found' });
  const { title = row.title, completed = Boolean(row.completed) } = req.body;
  db.prepare('UPDATE todos SET title = ?, completed = ? WHERE id = ?').run(title, completed ? 1 : 0, id);
  res.json(fmt(find(id)));
});

app.delete('/todos/:id', (req, res) => {
  const id = Number(req.params.id);
  if (!find(id)) return res.status(404).json({ error: 'Not found' });
  db.prepare('DELETE FROM todos WHERE id = ?').run(id);
  res.json({ message: 'deleted' });
});

app.listen(8080, () => console.log('Server on port 8080'));
