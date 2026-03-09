require 'sinatra/base'
require 'sqlite3'
require 'json'

class TodoApp < Sinatra::Base
  configure do
    set :port, 8080
    set :bind, '0.0.0.0'
  end

  def self.db
    @db ||= begin
      d = SQLite3::Database.new('todos.db')
      d.results_as_hash = true
      d.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS todos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          completed INTEGER DEFAULT 0,
          created_at TEXT DEFAULT (datetime('now'))
        )
      SQL
      d
    end
  end

  before { content_type :json }

  def db
    self.class.db
  end

  def serialize(row)
    {
      id: row['id'],
      title: row['title'],
      completed: row['completed'] == 1,
      created_at: row['created_at']
    }
  end

  get '/todos' do
    db.execute('SELECT * FROM todos').map { |r| serialize(r) }.to_json
  end

  post '/todos' do
    data = JSON.parse(request.body.read)
    halt 400, { error: 'title is required' }.to_json if data['title'].nil? || data['title'].empty?
    db.execute('INSERT INTO todos (title) VALUES (?)', data['title'])
    row = db.get_first_row('SELECT * FROM todos WHERE id = ?', db.last_insert_row_id)
    status 201
    serialize(row).to_json
  end

  put '/todos/:id' do
    id = params[:id].to_i
    row = db.get_first_row('SELECT * FROM todos WHERE id = ?', id)
    halt 404, { error: 'Not found' }.to_json unless row
    data = JSON.parse(request.body.read)
    title = data.key?('title') ? data['title'] : row['title']
    completed = data.key?('completed') ? (data['completed'] ? 1 : 0) : row['completed']
    db.execute('UPDATE todos SET title = ?, completed = ? WHERE id = ?', title, completed, id)
    serialize(db.get_first_row('SELECT * FROM todos WHERE id = ?', id)).to_json
  end

  delete '/todos/:id' do
    id = params[:id].to_i
    row = db.get_first_row('SELECT id FROM todos WHERE id = ?', id)
    halt 404, { error: 'Not found' }.to_json unless row
    db.execute('DELETE FROM todos WHERE id = ?', id)
    { message: 'deleted' }.to_json
  end

  run! if app_file == $0
end
