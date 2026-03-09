import express, { Application, Request, Response } from 'express';
import Database, { Database as DB } from 'better-sqlite3';

class TodoServer {
  private app: Application;
  private db: DB;
  private port = 8080;

  constructor() {
    this.app = express();
    this.db = new Database('todos.db');
    this.setupDatabase();
    this.setupMiddleware();
    this.setupRoutes();
  }

  private setupDatabase(): void {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS todos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        completed INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
      )
    `);
  }

  private setupMiddleware(): void {
    this.app.use(express.json());
  }

  private mapRow(row: any) {
    return { ...row, completed: !!row.completed };
  }

  private setupRoutes(): void {
    this.app.get('/todos', (req: Request, res: Response) => {
      const todos = this.db.prepare('SELECT * FROM todos').all().map(this.mapRow);
      res.json(todos);
    });

    this.app.post('/todos', (req: Request, res: Response) => {
      const { title } = req.body;
      if (!title) {
        return res.status(400).json({ error: 'title required' });
      }
      const stmt = this.db.prepare('INSERT INTO todos (title) VALUES (?)');
      const result = stmt.run(title);
      const todo = this.db.prepare('SELECT * FROM todos WHERE id = ?').get(result.lastInsertRowid);
      res.status(201).json(this.mapRow(todo));
    });

    this.app.put('/todos/:id', (req: Request, res: Response) => {
      const id = parseInt(req.params.id);
      const existing = this.db.prepare('SELECT * FROM todos WHERE id = ?').get(id) as any;
      if (!existing) {
        return res.status(404).json({ error: 'Not found' });
      }
      const title = req.body.title !== undefined ? req.body.title : existing.title;
      const completed = req.body.completed !== undefined ? (req.body.completed ? 1 : 0) : existing.completed;
      this.db.prepare('UPDATE todos SET title = ?, completed = ? WHERE id = ?').run(title, completed, id);
      const updated = this.db.prepare('SELECT * FROM todos WHERE id = ?').get(id);
      res.json(this.mapRow(updated));
    });

    this.app.delete('/todos/:id', (req: Request, res: Response) => {
      const id = parseInt(req.params.id);
      const existing = this.db.prepare('SELECT id FROM todos WHERE id = ?').get(id);
      if (!existing) {
        return res.status(404).json({ error: 'Not found' });
      }
      this.db.prepare('DELETE FROM todos WHERE id = ?').run(id);
      res.json({ message: 'deleted' });
    });
  }

  start(): void {
    this.app.listen(this.port, () => {
      console.log(`Server listening on port ${this.port}`);
    });
  }
}

const server = new TodoServer();
server.start();
