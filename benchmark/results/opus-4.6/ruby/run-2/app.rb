require "sinatra"
require "sqlite3"
require "json"
require "time"

set :port, 8080
set :bind, "0.0.0.0"

# --- Database Setup ---

DB_PATH = File.join(File.dirname(__FILE__), "todos.db")

def db
  @db ||= begin
    conn = SQLite3::Database.new(DB_PATH)
    conn.results_as_hash = true
    conn
  end
end

def init_db
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS todos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      completed BOOLEAN NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
  SQL
end

init_db

# --- Helpers ---

def todo_to_json(row)
  {
    id: row["id"],
    title: row["title"],
    completed: row["completed"] == 1,
    created_at: row["created_at"]
  }
end

before do
  content_type :json
end

# --- Endpoints ---

# GET /todos - List all todos
get "/todos" do
  rows = db.execute("SELECT * FROM todos")
  rows.map { |row| todo_to_json(row) }.to_json
end

# POST /todos - Create a new todo
post "/todos" do
  request_body = JSON.parse(request.body.read)
  title = request_body["title"]

  unless title && !title.strip.empty?
    status 400
    return { error: "title is required" }.to_json
  end

  created_at = Time.now.utc.iso8601

  db.execute(
    "INSERT INTO todos (title, completed, created_at) VALUES (?, ?, ?)",
    [title, 0, created_at]
  )

  id = db.last_insert_row_id
  row = db.execute("SELECT * FROM todos WHERE id = ?", [id]).first

  status 201
  todo_to_json(row).to_json
end

# PUT /todos/:id - Update a todo
put "/todos/:id" do
  id = params[:id].to_i
  row = db.execute("SELECT * FROM todos WHERE id = ?", [id]).first

  unless row
    status 404
    return { error: "not found" }.to_json
  end

  request_body = JSON.parse(request.body.read)

  title = request_body.key?("title") ? request_body["title"] : row["title"]
  completed = request_body.key?("completed") ? (request_body["completed"] ? 1 : 0) : row["completed"]

  db.execute(
    "UPDATE todos SET title = ?, completed = ? WHERE id = ?",
    [title, completed, id]
  )

  updated_row = db.execute("SELECT * FROM todos WHERE id = ?", [id]).first
  todo_to_json(updated_row).to_json
end

# DELETE /todos/:id - Delete a todo
delete "/todos/:id" do
  id = params[:id].to_i
  row = db.execute("SELECT * FROM todos WHERE id = ?", [id]).first

  unless row
    status 404
    return { error: "not found" }.to_json
  end

  db.execute("DELETE FROM todos WHERE id = ?", [id])
  { message: "deleted" }.to_json
end
