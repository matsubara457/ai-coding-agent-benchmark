require 'sinatra'
require 'sqlite3'
require 'json'

set :port, 8080
set :bind, '0.0.0.0'

configure do
  $db = SQLite3::Database.new('todos.db')
  $db.results_as_hash = true
  $db.execute(<<~SQL)
    CREATE TABLE IF NOT EXISTS todos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  SQL
end

before do
  content_type :json
  @body = begin
    JSON.parse(request.body.read)
  rescue
    {}
  end
end

helpers do
  def find_row(id)
    $db.get_first_row('SELECT * FROM todos WHERE id = ?', id.to_i)
  end

  def format_todo(r)
    { id: r['id'], title: r['title'], completed: r['completed'] == 1, created_at: r['created_at'] }
  end

  def not_found_json
    halt 404, { error: 'Not found' }.to_json
  end
end

get '/todos' do
  $db.execute('SELECT * FROM todos').map { |r| format_todo(r) }.to_json
end

post '/todos' do
  title = @body['title']
  halt 400, { error: 'title required' }.to_json unless title
  $db.execute('INSERT INTO todos (title) VALUES (?)', title)
  row = find_row($db.last_insert_row_id)
  status 201
  format_todo(row).to_json
end

put '/todos/:id' do
  row = find_row(params[:id]) || not_found_json
  title = @body.key?('title') ? @body['title'] : row['title']
  completed = @body.key?('completed') ? (@body['completed'] ? 1 : 0) : row['completed']
  $db.execute('UPDATE todos SET title = ?, completed = ? WHERE id = ?', title, completed, params[:id].to_i)
  format_todo(find_row(params[:id])).to_json
end

delete '/todos/:id' do
  find_row(params[:id]) || not_found_json
  $db.execute('DELETE FROM todos WHERE id = ?', params[:id].to_i)
  { message: 'deleted' }.to_json
end
