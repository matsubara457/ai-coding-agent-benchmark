import Fastify from 'fastify';
import Database from 'better-sqlite3';

const fastify = Fastify({ logger: false });
const PORT = 8080;

const db = new Database('todos.db');
db.exec(`
  CREATE TABLE IF NOT EXISTS todos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
`);

const toTodo = (r: any) => ({ id: r.id, title: r.title, completed: Boolean(r.completed), created_at: r.created_at });

fastify.get('/todos', async (_request, reply) => {
  const todos = db.prepare('SELECT * FROM todos').all().map(toTodo);
  return todos;
});

fastify.post('/todos', async (request, reply) => {
  const { title } = request.body as { title?: string };
  if (!title) {
    reply.code(400);
    return { error: 'title is required' };
  }
  const info = db.prepare('INSERT INTO todos (title) VALUES (?)').run(title);
  const todo = db.prepare('SELECT * FROM todos WHERE id = ?').get(info.lastInsertRowid);
  reply.code(201);
  return toTodo(todo);
});

fastify.put('/todos/:id', async (request, reply) => {
  const { id } = request.params as { id: string };
  const existing = db.prepare('SELECT * FROM todos WHERE id = ?').get(Number(id)) as any;
  if (!existing) {
    reply.code(404);
    return { error: 'Not found' };
  }
  const body = request.body as { title?: string; completed?: boolean };
  const title = body.title ?? existing.title;
  const completed = body.completed !== undefined ? body.completed : Boolean(existing.completed);
  db.prepare('UPDATE todos SET title = ?, completed = ? WHERE id = ?').run(title, completed ? 1 : 0, Number(id));
  const updated = db.prepare('SELECT * FROM todos WHERE id = ?').get(Number(id));
  return toTodo(updated);
});

fastify.delete('/todos/:id', async (request, reply) => {
  const { id } = request.params as { id: string };
  const existing = db.prepare('SELECT id FROM todos WHERE id = ?').get(Number(id));
  if (!existing) {
    reply.code(404);
    return { error: 'Not found' };
  }
  db.prepare('DELETE FROM todos WHERE id = ?').run(Number(id));
  return { message: 'deleted' };
});

fastify.listen({ port: PORT, host: '0.0.0.0' }, (err) => {
  if (err) {
    console.error(err);
    process.exit(1);
  }
  console.log(`Server running on port ${PORT}`);
});
