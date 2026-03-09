require 'sinatra'
require 'sqlite3'
require 'json'

set :port, 8080
set :bind, '0.0.0.0'

module DB
  def self.conn
    @conn ||= begin
      db = SQLite3::Database.new('todos.db')
      db.results_as_hash = true
      db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS todos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          completed INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      SQL
      db
    end
  end

  def self.all_todos
    conn.execute('SELECT * FROM todos ORDER BY id')
  end

  def self.find(id)
    conn.get_first_row('SELECT * FROM todos WHERE id = ?', id)
  end

  def self.create(title)
    conn.execute('INSERT INTO todos (title) VALUES (?)', title)
    find(conn.last_insert_row_id)
  end

  def self.update(id, title, completed)
    conn.execute('UPDATE todos SET title = ?, completed = ? WHERE id = ?', title, completed ? 1 : 0, id)
    find(id)
  end

  def self.delete(id)
    conn.execute('DELETE FROM todos WHERE id = ?', id)
  end
end

def to_json_todo(row)
  { id: row['id'], title: row['title'], completed: row['completed'] == 1, created_at: row['created_at'] }
end

before { content_type 'application/json' }

get '/todos' do
  DB.all_todos.map { |r| to_json_todo(r) }.to_json
end

post '/todos' do
  payload = JSON.parse(request.body.read) rescue {}
  halt 400, { error: 'title required' }.to_json unless payload['title']
  row = DB.create(payload['title'])
  status 201
  to_json_todo(row).to_json
end

put '/todos/:id' do
  id = params[:id].to_i
  row = DB.find(id)
  halt 404, { error: 'Not found' }.to_json unless row
  payload = JSON.parse(request.body.read) rescue {}
  title = payload.key?('title') ? payload['title'] : row['title']
  completed = payload.key?('completed') ? payload['completed'] : row['completed'] == 1
  to_json_todo(DB.update(id, title, completed)).to_json
end

delete '/todos/:id' do
  id = params[:id].to_i
  halt 404, { error: 'Not found' }.to_json unless DB.find(id)
  DB.delete(id)
  { message: 'deleted' }.to_json
end
