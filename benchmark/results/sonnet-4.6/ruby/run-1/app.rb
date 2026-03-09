require 'sinatra'
require 'sqlite3'
require 'json'

set :port, 8080
set :bind, '0.0.0.0'

DB = SQLite3::Database.new('todos.db')
DB.results_as_hash = true
DB.execute <<~SQL
  CREATE TABLE IF NOT EXISTS todos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
SQL

before do
  content_type :json
end

helpers do
  def fmt(row)
    { id: row['id'], title: row['title'], completed: row['completed'] == 1, created_at: row['created_at'] }
  end

  def find_todo(id)
    DB.get_first_row('SELECT * FROM todos WHERE id = ?', id)
  end
end

get '/todos' do
  todos = DB.execute('SELECT * FROM todos')
  todos.map { |r| fmt(r) }.to_json
end

post '/todos' do
  body = JSON.parse(request.body.read)
  halt 400, { error: 'title required' }.to_json unless body['title']
  DB.execute('INSERT INTO todos (title) VALUES (?)', body['title'])
  todo = find_todo(DB.last_insert_row_id)
  status 201
  fmt(todo).to_json
end

put '/todos/:id' do
  todo = find_todo(params[:id].to_i)
  halt 404, { error: 'Not found' }.to_json unless todo
  body = JSON.parse(request.body.read)
  title = body.key?('title') ? body['title'] : todo['title']
  completed = body.key?('completed') ? (body['completed'] ? 1 : 0) : todo['completed']
  DB.execute('UPDATE todos SET title = ?, completed = ? WHERE id = ?', title, completed, params[:id].to_i)
  fmt(find_todo(params[:id].to_i)).to_json
end

delete '/todos/:id' do
  todo = find_todo(params[:id].to_i)
  halt 404, { error: 'Not found' }.to_json unless todo
  DB.execute('DELETE FROM todos WHERE id = ?', params[:id].to_i)
  { message: 'deleted' }.to_json
end
