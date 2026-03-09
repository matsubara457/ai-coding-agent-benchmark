require "sinatra/base"
require "sqlite3"
require "json"
require "time"

class TodoApp < Sinatra::Base
  set :port, 8080
  set :bind, "0.0.0.0"
  set :server, :puma

  def self.db
    @db ||= begin
      db = SQLite3::Database.new("todos.db")
      db.results_as_hash = true
      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS todos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          completed BOOLEAN NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      SQL
      db
    end
  end

  before do
    content_type :json
  end

  helpers do
    def db
      self.class.db
    end

    def format_todo(row)
      {
        id: row["id"],
        title: row["title"],
        completed: row["completed"] == 1,
        created_at: row["created_at"]
      }
    end

    def parse_body
      body = request.body.read
      return {} if body.empty?
      JSON.parse(body)
    rescue JSON::ParserError
      halt 400, { error: "Invalid JSON" }.to_json
    end
  end

  # GET /todos - List all todos
  get "/todos" do
    rows = db.execute("SELECT * FROM todos")
    rows.map { |row| format_todo(row) }.to_json
  end

  # POST /todos - Create a new todo
  post "/todos" do
    data = parse_body
    title = data["title"]

    halt 400, { error: "title is required" }.to_json if title.nil? || title.strip.empty?

    created_at = Time.now.utc.iso8601

    db.execute(
      "INSERT INTO todos (title, completed, created_at) VALUES (?, ?, ?)",
      [title, 0, created_at]
    )

    id = db.last_insert_row_id
    row = db.execute("SELECT * FROM todos WHERE id = ?", [id]).first

    status 201
    format_todo(row).to_json
  end

  # PUT /todos/:id - Update a todo
  put "/todos/:id" do
    id = params[:id].to_i
    row = db.execute("SELECT * FROM todos WHERE id = ?", [id]).first

    halt 404, { error: "Todo not found" }.to_json unless row

    data = parse_body

    title = data.key?("title") ? data["title"] : row["title"]
    completed = data.key?("completed") ? (data["completed"] ? 1 : 0) : row["completed"]

    db.execute(
      "UPDATE todos SET title = ?, completed = ? WHERE id = ?",
      [title, completed, id]
    )

    row = db.execute("SELECT * FROM todos WHERE id = ?", [id]).first
    format_todo(row).to_json
  end

  # DELETE /todos/:id - Delete a todo
  delete "/todos/:id" do
    id = params[:id].to_i
    row = db.execute("SELECT * FROM todos WHERE id = ?", [id]).first

    halt 404, { error: "Todo not found" }.to_json unless row

    db.execute("DELETE FROM todos WHERE id = ?", [id])
    { message: "deleted" }.to_json
  end

  run! if __FILE__ == $0
end
