require 'sinatra'
require 'sqlite3'
require 'json'

set :port, 8080
set :bind, '0.0.0.0'

DB = SQLite3::Database.new('todos.db').tap do |d|
  d.results_as_hash = true
  d.execute('CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, completed INTEGER DEFAULT 0, created_at TEXT DEFAULT (datetime(\'now\')))')
end

before { content_type :json }

def row(id) = DB.get_first_row('SELECT * FROM todos WHERE id=?', id.to_i)
def fmt(r) = { id: r['id'], title: r['title'], completed: r['completed']==1, created_at: r['created_at'] }

get '/todos' do
  DB.execute('SELECT * FROM todos').map{|r| fmt(r)}.to_json
end

post '/todos' do
  b = JSON.parse(request.body.read) rescue {}
  halt 400, {error:'title required'}.to_json unless b['title']
  DB.execute('INSERT INTO todos (title) VALUES (?)', b['title'])
  status 201; fmt(row(DB.last_insert_row_id)).to_json
end

put '/todos/:id' do
  r = row(params[:id]); halt 404, {error:'Not found'}.to_json unless r
  b = JSON.parse(request.body.read) rescue {}
  t = b.key?('title') ? b['title'] : r['title']
  c = b.key?('completed') ? (b['completed'] ? 1 : 0) : r['completed']
  DB.execute('UPDATE todos SET title=?,completed=? WHERE id=?', t, c, params[:id].to_i)
  fmt(row(params[:id])).to_json
end

delete '/todos/:id' do
  halt 404, {error:'Not found'}.to_json unless row(params[:id])
  DB.execute('DELETE FROM todos WHERE id=?', params[:id].to_i)
  {message:'deleted'}.to_json
end
