use actix_web::{web, App, HttpServer, HttpResponse, middleware};
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};

#[derive(Debug, Serialize, Deserialize, Clone)]
struct Todo {
    id: i64,
    title: String,
    completed: bool,
    created_at: String,
}

#[derive(Deserialize)]
struct CreateTodo {
    title: String,
}

#[derive(Deserialize)]
struct UpdateTodo {
    title: Option<String>,
    completed: Option<bool>,
}

type DbPool = Arc<Mutex<Connection>>;

fn init_db(conn: &Connection) {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            completed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )"
    ).unwrap();
}

fn row_to_todo(row: &rusqlite::Row) -> rusqlite::Result<Todo> {
    Ok(Todo {
        id: row.get(0)?,
        title: row.get(1)?,
        completed: row.get::<_, i64>(2)? != 0,
        created_at: row.get(3)?,
    })
}

async fn get_todos(db: web::Data<DbPool>) -> HttpResponse {
    let conn = db.lock().unwrap();
    let mut stmt = conn.prepare("SELECT id, title, completed, created_at FROM todos").unwrap();
    let todos: Vec<Todo> = stmt.query_map([], row_to_todo).unwrap()
        .filter_map(Result::ok).collect();
    HttpResponse::Ok().json(todos)
}

async fn create_todo(db: web::Data<DbPool>, body: web::Json<CreateTodo>) -> HttpResponse {
    let conn = db.lock().unwrap();
    conn.execute("INSERT INTO todos (title) VALUES (?1)", params![body.title]).unwrap();
    let id = conn.last_insert_rowid();
    let todo = conn.query_row(
        "SELECT id, title, completed, created_at FROM todos WHERE id = ?1",
        params![id], row_to_todo
    ).unwrap();
    HttpResponse::Created().json(todo)
}

async fn update_todo(
    db: web::Data<DbPool>,
    path: web::Path<i64>,
    body: web::Json<UpdateTodo>,
) -> HttpResponse {
    let id = path.into_inner();
    let conn = db.lock().unwrap();
    let existing = conn.query_row(
        "SELECT id, title, completed, created_at FROM todos WHERE id = ?1",
        params![id], row_to_todo
    );
    match existing {
        Err(_) => HttpResponse::NotFound().json(serde_json::json!({"error": "Not found"})),
        Ok(e) => {
            let title = body.title.clone().unwrap_or(e.title);
            let completed = body.completed.unwrap_or(e.completed);
            conn.execute(
                "UPDATE todos SET title = ?1, completed = ?2 WHERE id = ?3",
                params![title, completed as i64, id]
            ).unwrap();
            let updated = conn.query_row(
                "SELECT id, title, completed, created_at FROM todos WHERE id = ?1",
                params![id], row_to_todo
            ).unwrap();
            HttpResponse::Ok().json(updated)
        }
    }
}

async fn delete_todo(db: web::Data<DbPool>, path: web::Path<i64>) -> HttpResponse {
    let id = path.into_inner();
    let conn = db.lock().unwrap();
    let count: i64 = conn.query_row(
        "SELECT COUNT(*) FROM todos WHERE id = ?1", params![id],
        |row| row.get(0)
    ).unwrap_or(0);
    if count == 0 {
        return HttpResponse::NotFound().json(serde_json::json!({"error": "Not found"}));
    }
    conn.execute("DELETE FROM todos WHERE id = ?1", params![id]).unwrap();
    HttpResponse::Ok().json(serde_json::json!({"message": "deleted"}))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let conn = Connection::open("todos.db").unwrap();
    init_db(&conn);
    let db: DbPool = Arc::new(Mutex::new(conn));

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(db.clone()))
            .route("/todos", web::get().to(get_todos))
            .route("/todos", web::post().to(create_todo))
            .route("/todos/{id}", web::put().to(update_todo))
            .route("/todos/{id}", web::delete().to(delete_todo))
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}
