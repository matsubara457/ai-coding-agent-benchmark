use actix_web::{web, App, HttpServer, HttpResponse, ResponseError};
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};
use std::fmt;

#[derive(Debug, Serialize, Deserialize)]
struct Todo {
    id: i64,
    title: String,
    completed: bool,
    created_at: String,
}

#[derive(Deserialize)]
struct TodoCreate { title: String }

#[derive(Deserialize)]
struct TodoUpdate {
    title: Option<String>,
    completed: Option<bool>,
}

#[derive(Debug)]
enum AppError {
    NotFound,
    DbError(rusqlite::Error),
}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            AppError::NotFound => write!(f, "Not found"),
            AppError::DbError(e) => write!(f, "DB error: {}", e),
        }
    }
}

impl ResponseError for AppError {
    fn error_response(&self) -> HttpResponse {
        match self {
            AppError::NotFound => HttpResponse::NotFound().json(serde_json::json!({"error": "Not found"})),
            AppError::DbError(_) => HttpResponse::InternalServerError().json(serde_json::json!({"error": "Internal error"})),
        }
    }
}

type Db = Arc<Mutex<Connection>>;

fn map_todo(row: &rusqlite::Row) -> rusqlite::Result<Todo> {
    Ok(Todo {
        id: row.get(0)?,
        title: row.get(1)?,
        completed: row.get::<_, i64>(2)? != 0,
        created_at: row.get(3)?,
    })
}

async fn list_todos(db: web::Data<Db>) -> Result<HttpResponse, AppError> {
    let conn = db.lock().unwrap();
    let mut stmt = conn.prepare("SELECT id, title, completed, created_at FROM todos")
        .map_err(AppError::DbError)?;
    let todos: Vec<Todo> = stmt.query_map([], map_todo)
        .map_err(AppError::DbError)?
        .filter_map(Result::ok)
        .collect();
    Ok(HttpResponse::Ok().json(todos))
}

async fn create_todo(db: web::Data<Db>, body: web::Json<TodoCreate>) -> Result<HttpResponse, AppError> {
    let conn = db.lock().unwrap();
    conn.execute("INSERT INTO todos (title) VALUES (?1)", params![body.title])
        .map_err(AppError::DbError)?;
    let id = conn.last_insert_rowid();
    let todo = conn.query_row(
        "SELECT id, title, completed, created_at FROM todos WHERE id = ?1",
        params![id], map_todo
    ).map_err(AppError::DbError)?;
    Ok(HttpResponse::Created().json(todo))
}

async fn update_todo(
    db: web::Data<Db>,
    path: web::Path<i64>,
    body: web::Json<TodoUpdate>,
) -> Result<HttpResponse, AppError> {
    let id = path.into_inner();
    let conn = db.lock().unwrap();
    let existing = conn.query_row(
        "SELECT id, title, completed, created_at FROM todos WHERE id = ?1",
        params![id], map_todo
    ).map_err(|_| AppError::NotFound)?;
    let title = body.title.clone().unwrap_or(existing.title);
    let completed = body.completed.unwrap_or(existing.completed);
    conn.execute(
        "UPDATE todos SET title = ?1, completed = ?2 WHERE id = ?3",
        params![title, completed as i64, id]
    ).map_err(AppError::DbError)?;
    let updated = conn.query_row(
        "SELECT id, title, completed, created_at FROM todos WHERE id = ?1",
        params![id], map_todo
    ).map_err(AppError::DbError)?;
    Ok(HttpResponse::Ok().json(updated))
}

async fn delete_todo(db: web::Data<Db>, path: web::Path<i64>) -> Result<HttpResponse, AppError> {
    let id = path.into_inner();
    let conn = db.lock().unwrap();
    let exists: bool = conn.query_row(
        "SELECT EXISTS(SELECT 1 FROM todos WHERE id = ?1)", params![id],
        |row| row.get(0)
    ).map_err(AppError::DbError)?;
    if !exists {
        return Err(AppError::NotFound);
    }
    conn.execute("DELETE FROM todos WHERE id = ?1", params![id])
        .map_err(AppError::DbError)?;
    Ok(HttpResponse::Ok().json(serde_json::json!({"message": "deleted"})))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let conn = Connection::open("todos.db").unwrap();
    conn.execute_batch("CREATE TABLE IF NOT EXISTS todos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )").unwrap();
    let db: Db = Arc::new(Mutex::new(conn));
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(db.clone()))
            .route("/todos", web::get().to(list_todos))
            .route("/todos", web::post().to(create_todo))
            .route("/todos/{id}", web::put().to(update_todo))
            .route("/todos/{id}", web::delete().to(delete_todo))
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}
