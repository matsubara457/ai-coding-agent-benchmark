require "sinatra/base"
require "sqlite3"
require "json"

class TodoApp < Sinatra::Base
  set :port, 8080
  set :bind, "0.0.0.0"
  set :server, :puma

  DB_PATH = File.join(__dir__, "todos.db")

  def self.db
    @db ||= begin
      db = SQLite3::Database.new(DB_PATH)
      db.results_as_hash = true
      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS todos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          completed BOOLEAN NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
        );
      SQL
      db
    end
  end

  helpers do
    def db
      self.class.db
    end

    def parse_json_body
      body = request.body.read
      return {} if body.empty?
      JSON.parse(body)
    rescue JSON::ParserError
      halt 400, { "Content-Type" => "application/json" }, { error: "Invalid JSON" }.to_json
    end

    def format_todo(row)
      {
        id: row["id"],
        title: row["title"],
        completed: row["completed"] == 1,
        created_at: row["created_at"]
      }
    end
  end

  before do
    content_type :json
  end

  # GET /todos - List all todos
  get "/todos" do
    rows = db.execute("SELECT * FROM todos")
    rows.map { |row| format_todo(row) }.to_json
  end

  # POST /todos - Create a new todo
  post "/todos" do
    data = parse_json_body
    title = data["title"]

    halt 400, { error: "title is required" }.to_json if title.nil? || title.strip.empty?

    db.execute("INSERT INTO todos (title) VALUES (?)", [title])
    id = db.last_insert_row_id
    row = db.execute("SELECT * FROM todos WHERE id = ?", [id]).first

    status 201
    format_todo(row).to_json
  end

  # PUT /todos/:id - Update a todo
  put "/todos/:id" do
    id = params["id"]
    row = db.execute("SELECT * FROM todos WHERE id = ?", [id]).first
    halt 404, { error: "not found" }.to_json unless row

    data = parse_json_body
    title = data.key?("title") ? data["title"] : row["title"]
    completed = data.key?("completed") ? (data["completed"] ? 1 : 0) : row["completed"]

    db.execute("UPDATE todos SET title = ?, completed = ? WHERE id = ?", [title, completed, id])
    row = db.execute("SELECT * FROM todos WHERE id = ?", [id]).first

    format_todo(row).to_json
  end

  # DELETE /todos/:id - Delete a todo
  delete "/todos/:id" do
    id = params["id"]
    row = db.execute("SELECT * FROM todos WHERE id = ?", [id]).first
    halt 404, { error: "not found" }.to_json unless row

    db.execute("DELETE FROM todos WHERE id = ?", [id])
    { message: "deleted" }.to_json
  end

  run! if __FILE__ == $0
end
